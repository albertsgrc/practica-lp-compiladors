/* ############################# */
/* # G L O B A L   H E A D E R S */
/* ############################# */

#header
<<
#include <string>
#include <iostream>
using namespace std;

// Struct to store information about tokens

typedef struct {
	string kind;
	string text;
} Attrib;

// Function to fill token information (predeclaration)

void zzcr_attr(Attrib *attr, int type, char *text);

// Fields for AST nodes

#define AST_FIELDS string kind; string text;
#include "ast.h"

// Macro to create a new AST node (and function predeclaration)

#define zzcr_ast(as,attr,ttype,textt) as=createASTnode(attr,ttype,textt)
AST* createASTnode(Attrib* attr,int ttype, char *textt);
>>

/* ######### */
/* # C O D E */
/* ######### */

<<
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <unordered_set>
#include <unordered_map>
#include <stdio.h>

#include <cassert>
#include <unistd.h>


/* ################################################# */
/* ## T O K E N    A N D    A S T    H A N D L I N G */
/* ################################################# */

// Function to fill token information
void zzcr_attr(Attrib *attr, int type, char *text) {
	if (type == ID) {
		attr->kind = "id";
		attr->text = text;
	}
	else {
		attr->kind = text;
		attr->text = "";
}   }

// Function to create a new AST node
AST* createASTnode(Attrib* attr, int type, char* text) {
	AST* as = new AST;

	as->kind = attr->kind; 
	as->text = attr->text;
	as->right = NULL; 
	as->down = NULL;

	return as;
}

// Create a new "list" AST node with one element
AST* createASTlist(AST *child) {
	AST* as = new AST;

	as->kind = "list";
	as->right = NULL;
	as->down = child;

	return as;
}

// Get nth child of a tree. Count starts at 0.
// If no such child, returns NULL
AST* child(AST* a, int n) {
	AST* c = a->down;

	for (int i = 0; c != NULL and i < n; ++i) c = c->right;

	return c;
}

// Print AST recursively, with indentation
void ASTPrintIndent(AST* a, string s) {
	if (a == NULL) return;

	cout << a->kind;
	if (a->text != "") cout << "(" << a->text << ")";
	cout << endl;

	AST* i = a->down;
	while (i != NULL and i->right != NULL) {
		cout << s + "  \\__";
		ASTPrintIndent(i, s + "  |" + string(i->kind.size() + 
                                             i->text.size(), ' '));
		i = i->right;
	}

	if (i != NULL) {
		cout << s + "  \\__";
		ASTPrintIndent(i, s + "   " + string(i->kind.size() +
                                             i->text.size(), ' '));
		i = i->right;
}   }

// Print AST
void ASTPrint(AST* a) {
	while (a != NULL) {
		cout << " ";
		ASTPrintIndent(a, "");
		a = a->right;
}	}

inline AST* advance(AST*& a) {
	return a = a->right;
}

/* ####################################### */
/* ## A S T    I N T E R P R E T A T I O N */
/* ####################################### */

/* ################### */
/* ### Data structures */
/* ################### */


// # Orientation
enum class Orientation { UP, RIGHT, DOWN, LEFT };

// # Position
struct Position {
	int x, y;

	Position() {}
	Position(int x, int y) : x(x), y(y) {} 
	Position(const Position& p) : x(p.x), y(p.y) {}

	bool insideWorld() const;
	bool hasBeeper() const;

	inline bool operator==(const Position& other) const {
		return other.x == x and other.y == y;
	}

	inline Position& operator+=(const Orientation& orientation) {
		switch (orientation) {
			case Orientation::UP: --y; break;
			case Orientation::RIGHT: ++x; break;
			case Orientation::DOWN: ++y; break;
			case Orientation::LEFT: --x; break;
		}

		return *this;
	}

	inline Position operator+(const Orientation& orientation) const {
		Position res(*this);
		return res += orientation; 
	}

	friend ostream& operator<<(ostream& s, const Position& position) {
		s << position.x << ' ' << position.y;
		return s;
	}
};

// # Pose (Position + Orientation)
struct Pose {
	Position position;
	Orientation orientation;

	Pose() {}
	Pose(const Position& p, Orientation o) : position(p), orientation(o) {}

	bool isClear() const;

	Position nextPosition() {
		return position + orientation;
	}

	void advance() {
		position += orientation;
	}

	bool operator==(const Pose& other) const {
		return other.position == position and 
               other.orientation == orientation;
	}
};

// Hashing function definitions for Position and Pose
template <class T> inline void hash_combine(size_t& seed, const T& v) {
	hash<T> hasher; seed ^= hasher(v) + 0x9e3779b9 + (seed*64) + (seed/4); 
}
namespace std {
	template <> struct hash<Position> {
		size_t operator()(const Position& position) const {
			size_t seed = 0;
			hash_combine(seed, position.x); 
			hash_combine(seed, position.y);
			return seed; 
	}   };
	template <> struct hash<Pose> { 
		size_t operator()(const Pose& pose) const {
			size_t seed = 0;
			hash_combine(seed, pose.position); 
			hash_combine(seed, static_cast<int>(pose.orientation));
			return seed;
}   };  }

// # World
struct World {
	int sizeX, sizeY;

	unordered_set<Pose> walls;
	unordered_map<Position, int> beepers;

	void initialize(AST*);
	void addBeeper(AST*);
	void addWalls(AST*);
	void putBeeper(const Position&);
	bool pickBeeper(const Position&);
};

// # Robot
struct Robot {
	Pose pose;

	bool isOn; 

	int beeperCount;

	void turnOff() {
		isOn = false;
	}

	void initialize(AST*);
	void turnLeft();
	void move();
	void pickBeeper();
	void putBeeper();
	bool foundBeeper();
};

// # Function definitions
// Implements finding function definitions in O(1) average
class FunctionDefinitions {
	private:
		unordered_map<string, AST*> map;

	public:
		inline void add(AST* definition) {
			string id = definition->text;
			AST* insList = definition->right;
			map[id] = child(insList, 0);
		}

		inline AST* get(const string& id) const {
			auto it = map.find(id);

			if (it == map.end()) {
				cerr << "Definition not found: " << id << " " << endl;
				return NULL;
			}
			else return it->second;
		}
};

/* ################################# */
/* ### Data structures instantiation */
/* ################################# */

World world;

Robot robot;

FunctionDefinitions functionDefinitions;

/* ########### */
/* ### Methods */
/* ########### */

// # Utils

// To parse strings to integers
inline int sti(const string& s) { 
	return atoi(s.c_str());
}

// # Orientation

inline Orientation sToOrientation(const string& s) {
	switch (s[0]) {
		case 'u': return Orientation::UP;
		case 'r': return Orientation::RIGHT;
		case 'd': return Orientation::DOWN;
		case 'l': return Orientation::LEFT;
	}
}

inline Orientation opposite(Orientation o) {
	switch(o) {
		case Orientation::LEFT: return Orientation::RIGHT;
		case Orientation::RIGHT: return Orientation::LEFT;
		case Orientation::UP: return Orientation::DOWN;
		case Orientation::DOWN: return Orientation::UP;
	}
}

// # Position

inline bool Position::insideWorld() const {
	return 0 <= this->x and this->x < world.sizeX 
			and 
		   0 <= this->y and this->y < world.sizeY;
}

inline bool Position::hasBeeper() const {
	auto it = world.beepers.find(*this);
	return it != world.beepers.end() and it->second > 0; 
}

// # Pose

inline Pose equivalentWall(const Pose& wall) {
	return Pose(wall.position + wall.orientation, opposite(wall.orientation));
}

inline bool Pose::isClear() const {
	return world.walls.find(*this) == world.walls.end() and 
	       world.walls.find(equivalentWall(*this)) == world.walls.end();
}

// # World

void World::initialize(AST* worldNode) {
	this->sizeX = sti(worldNode->kind);
	this->sizeY = sti(worldNode->right->kind);
}

void World::addBeeper(AST* beeperNode) {
    // On repeated calls with same position replaces previous value
	AST* xNode = beeperNode;
	AST* yNode = xNode->right;
	AST* amountNode = yNode->right;

	Position position(sti(xNode->kind), sti(yNode->kind));
	int amount = sti(amountNode->kind);

	beepers[position] = amount;
}

void World::addWalls(AST* wallsNode) {
	while (wallsNode != NULL) {
		AST* xNode = wallsNode;
		AST* yNode = advance(wallsNode);
		AST* orientationNode = advance(wallsNode);

		Position position(sti(xNode->kind), sti(yNode->kind));
		Pose pose(position, sToOrientation(orientationNode->kind));

		this->walls.insert(pose);

		advance(wallsNode);
	}
}

void World::putBeeper(const Position& position) {
	auto it = this->beepers.find(position);

	if (it == this->beepers.end())
        this->beepers.insert(it, make_pair(position, 1));
	else ++it->second;
}

bool World::pickBeeper(const Position& position) {
	auto it = this->beepers.find(position);

	bool picked = it != this->beepers.end() and it->second > 0;
	if (picked) --it->second;

	return picked;
}

// # Robot

void Robot::initialize(AST* robotNode) {
	AST* xNode = robotNode;
	AST* yNode = xNode->right;
	AST* beeperCountNode = yNode->right;
	AST* orientationNode = beeperCountNode->right;

	this->pose.position.x = sti(xNode->kind);
	this->pose.position.y = sti(yNode->kind);
	this->beeperCount = sti(beeperCountNode->kind);
	this->pose.orientation = sToOrientation(orientationNode->kind);
	
	this->isOn = true;
}

void Robot::turnLeft() {
	if (not isOn) return;

	switch (pose.orientation) {
		case Orientation::UP: pose.orientation = Orientation::LEFT; break;
		case Orientation::RIGHT: pose.orientation = Orientation::UP; break;
		case Orientation::DOWN: pose.orientation = Orientation::RIGHT; break;
		case Orientation::LEFT: pose.orientation = Orientation::DOWN; break;
	}
}

void Robot::move() {
	if (not isOn) return;

	Position destiny = this->pose.nextPosition();

	if (destiny.insideWorld() and this->pose.isClear()) this->pose.advance();
}

void Robot::pickBeeper() {
	if (not isOn) return;

	if (world.pickBeeper(pose.position)) ++beeperCount;
	else cerr << "Cannot pick beeper because there's no beeper in the current"
              << " robot's position!" << endl;
}

void Robot::putBeeper() {
	if (not isOn) return;

	if (beeperCount > 0) {
		--beeperCount;
		world.putBeeper(pose.position);
	}
	else cerr << "Cannot put beeper because robot has no beepers left!" << endl; 
}

bool Robot::foundBeeper() {
	return pose.position.hasBeeper();
}

// Funcions enunciat (no usades)

AST* findDefinition(string id) { return functionDefinitions.get(id); }
bool dinsDominis(int x, int y) { return Position(x, y).insideWorld(); }
bool isClear(int x, int y, int orient) { 
    return Pose(Position(x, y), static_cast<Orientation>(orient)).isClear(); 
}

// # Debugging

class Debugger {
	private:

    bool debugging_instr;
    bool enabled;
    bool colors;
    
    const char WALL = '#';
    const char NOTHING = ' ';

    const char ROBOT_LEFT = '<';
    const char ROBOT_RIGHT = '>';
    const char ROBOT_UP = '^';
    const char ROBOT_DOWN = 'V';

    const char wallStyle[8] = { 0x1b,'[','1',';','3','7','m',0 };
    const char robotStyle[8] = { 0x1b,'[','1',';','3','6','m',0 };
    const char sensorStyle[8] = { 0x1b,'[','1',';','3','5','m',0 };
    const char backgroundStyle[8] = { 0x1b,'[','0',';','4','0','m',0 };
    const char backgroundNormal[8] = { 0x1b,'[','1',';','4','9','m',0 };
    const char normalStyle[8] = { 0x1b,'[','1',';','3','9','m',0 };
    const char defaultCellStyle[8] = { 0x1b,'[','1',';','3','0','m',0 };

    const unordered_set<string> ins_debug = {
        "turnleft", 
        "move", 
        "pickbeeper", 
        "putbeeper", 
        "turnoff" 
    };
    
    const string cellFormat[3] = {
        "WTTTO",
        "LUXSR",
        "YBBBV"
    };

    const int N_ROWS = 2;
    const int N_COLS = 4;

    const int FRAME_RATE_PER_SEC = 4;

    void setStyle(const char style[]) {
        if (colors) cout << style;
    }

    void printWithStyle(bool condition, char c, const char style[]) {
        if (condition) {
            setStyle(style); cout << c; setStyle(defaultCellStyle);
        }
        else cout << NOTHING;
    }

    void printWall(bool condition) {
        if (condition) {
            setStyle(wallStyle); cout << WALL; setStyle(defaultCellStyle);
        }
        else cout << WALL;
    }

    void printUnlessRobotAndSensors(bool thereIsRobot, int sensors) {
        if (thereIsRobot != sensors > 0) {
            if (thereIsRobot) {
                setStyle(robotStyle); cout << robotChar(); setStyle(defaultCellStyle);
            }
            else {
                setStyle(sensorStyle); cout << sensors%10; setStyle(defaultCellStyle);
            }
        }
        else cout << NOTHING;
    }

    char robotChar() {
        switch (robot.pose.orientation) {
            case Orientation::LEFT: return ROBOT_LEFT; 
            case Orientation::RIGHT: return ROBOT_RIGHT;
            case Orientation::UP: return ROBOT_UP;
            case Orientation::DOWN: return ROBOT_DOWN;
        }
    }

    void printCellElem(int row, int col, int x, int y, bool fC1 = false, bool fC2 = false) {
        Position position(x, y);

        bool leftWall = not Pose(position, Orientation::LEFT).isClear();
        bool rightWall = not Pose(position, Orientation::RIGHT).isClear();
        bool upWall = not Pose(position, Orientation::UP).isClear();
        bool downWall = not Pose(position, Orientation::DOWN).isClear();

        bool thereIsRobot = robot.pose.position == position;

        bool isFuckedUpCorner = (fC1 and (not 
                                Pose(position + Orientation::UP,
                                     Orientation::LEFT).isClear()) or
                                     not Pose(position + Orientation::LEFT, 
                                     Orientation::UP).isClear())
                                     or 
                                (fC2 and not 
                                Pose(position + Orientation::UP, 
                                     Orientation::RIGHT).isClear());

        auto it = world.beepers.find(position);
        int sensors = it == world.beepers.end() ? 0 : it->second;

        switch(cellFormat[row][col]) {
            case 'W': printWall(leftWall or upWall or isFuckedUpCorner); break;
            case 'L': printWall(leftWall); break;
            case 'Y': printWall(leftWall or downWall); break;
            case 'B': printWall(downWall); break;
            case 'T': printWall(upWall); break;
            case 'O': printWall(upWall or rightWall or isFuckedUpCorner); break;
            case 'R': printWall(rightWall); break;
            case 'V': printWall(downWall or rightWall); break;
            case 'X': printUnlessRobotAndSensors(thereIsRobot, sensors); break;
            case 'U': printWithStyle(thereIsRobot and sensors, 
                                     robotChar(), robotStyle); break;
            case 'S': printWithStyle(thereIsRobot and sensors, 
                                     char(sensors%10 + '0'), sensorStyle); break;
        }
    }

	public:

    Debugger() : enabled(true), debugging_instr(false) {
        colors = isatty(fileno(stdout));
    }

    inline void debugInstructions(bool b) { debugging_instr = b; }

    inline void disable() { enabled = false; }

    inline void enable() { enabled = true; }

    void printWorld(const string& msg, bool special = false) {
        if (not enabled) return;
        if (not special and (not debugging_instr 
            or ins_debug.find(msg) == ins_debug.end())) return;

        cout << endl;

        setStyle(backgroundNormal); setStyle(normalStyle);
        
        cout << msg << ":" << endl;

        setStyle(backgroundStyle); setStyle(defaultCellStyle);

        for (int y = 0; y < world.sizeY; ++y) {
            for (int row = 0; row < N_ROWS; ++row) {
                for (int x = 0; x < world.sizeX; ++x) {
                    for (int col = 0; col < N_COLS; ++col)
                        printCellElem(row, col, x, y, row == 0 and col == 0);
                }
                printCellElem(row, N_COLS, world.sizeX - 1, y, false, true);
                cout << endl;
            }
        }

        for (int i = 0; i < N_COLS*world.sizeX + 1; ++i)
            printCellElem(N_ROWS, i%(N_COLS + 1), i/(N_COLS + 1), world.sizeY - 1);
        
        cout << endl;
        
        setStyle(backgroundNormal); setStyle(normalStyle);
        
        cout << "Robot: "
             << (robot.isOn ? "ON, " : "OFF, ") << robot.beeperCount 
             << " beepers" << endl;

        if (not special) usleep(1000000/FRAME_RATE_PER_SEC);
    }
};

Debugger debugger;

// # Evaluation

bool avaluaCondicio(AST* a) {
	AST* fc;

	if (a->kind == "foundBeeper") return robot.foundBeeper();
	else if (a->kind == "isClear") return robot.pose.isClear();
	else if (a->kind == "anyBeepersInBag") return robot.beeperCount > 0;
	else if (a->kind == "not") return not avaluaCondicio(child(a, 0));
	else if (a->kind == "and") {
		fc = child(a, 0); 
		return avaluaCondicio(fc) and avaluaCondicio(fc->right);
	}
	else if (a->kind == "or") {
		fc = child(a, 0);
		return avaluaCondicio(fc) or avaluaCondicio(fc->right);	
	}
}

void evaluateDefinitions(AST* def) {
	while (def != NULL) {
		if (def->kind == "walls") world.addWalls(child(def, 0));
		else if (def->kind == "beepers") world.addBeeper(child(def, 0));
		else if (def->kind == "define") functionDefinitions.add(child(def, 0));

		advance(def);
	}
}

void evaluateInstructions(AST*);

void evaluateIterate(AST* iterate) {
	int times = sti(iterate->kind);
	AST* insList = iterate->right;
	while (times--) evaluateInstructions(child(insList, 0));
} 

void evaluateIf(AST* _if) {
	if (avaluaCondicio(_if)) evaluateInstructions(child(_if->right, 0));
}

void evaluateInstructions(AST* instr) {
	while (instr != NULL) {
		if (instr->kind == "iterate") evaluateIterate(child(instr, 0));
		else if (instr->kind == "if") evaluateIf(child(instr, 0));
		else if (instr->kind == "turnleft") robot.turnLeft();
		else if (instr->kind == "move") robot.move();
		else if (instr->kind == "putbeeper") robot.putBeeper();
		else if (instr->kind == "pickbeeper") robot.pickBeeper();
		else if (instr->kind == "id") 
            evaluateInstructions(functionDefinitions.get(instr->text)); 
		else if (instr->kind == "turnoff") robot.turnOff();

        debugger.printWorld(instr->kind);

		advance(instr);
	}
}

// # Main methods

void novaPosicio(AST* root) {
	AST* worldNode = child(root, 0);
	AST* robotNode = worldNode->right;
	AST* definitionsList = robotNode->right;
	AST* instructionsList = definitionsList->right;
	
	world.initialize(child(worldNode, 0)); 
	robot.initialize(child(robotNode, 0));

	evaluateDefinitions(child(definitionsList, 0));
	
	debugger.printWorld("BEGGINING", true);

	evaluateInstructions(child(instructionsList, 0));
    
    debugger.printWorld("END", true);
    
	cout << endl << "Ending position: " << robot.pose.position << endl;
}

int main(int argc, char** argv) {
	AST* root = NULL;
	
	ANTLR(karel(&root), stdin);

	ASTPrint(root);
	
    if (argc > 1) {
        if (strcmp(argv[1], "-nd") == 0) debugger.disable();
        else if (strcmp(argv[1], "-v") == 0) debugger.debugInstructions(true);
    }

	novaPosicio(root); 
}
>>

/* ############################################################# */
/* # L E X I C O N   A N D   S Y N T A X   D E F I N I T I O N S */
/* ############################################################# */

#lexclass START

/* ##################### */
/* ### Token definitions */
/* ##################### */

// Logic operators

#token AND "and"
#token OR "or"
#token NOT "not"

// Global tokens

#token WORLD "world"
#token ROBOT "robot"

// Definitions

#token WALLS "walls"
#token BEEPERS "beepers"

#token DEFINE "define"

// Orientations

#token TLEFT "left"
#token TRIGHT "right"
#token TUP "up"
#token TDOWN "down"

// Instructions

#token TURNLEFT "turnleft"
#token MOVE "move"
#token PUTBEEPER "putbeeper"
#token PICKBEEPER "pickbeeper"

#token TURNOFF "turnoff"

// Instruction flow control

#token IF "if"
#token ITERATE "iterate"

// Boolean queries

#token FOUNDBEEPER "foundBeeper"
#token ISCLEAR "isClear"
#token ANYBEEPERSINBAG "anyBeepersInBag"

// Delimiters

#token COMMA ","

#token SEMICOLON ";"

#token LCURLYBRACKET "\{"
#token RCURLYBRACKET "\}"

#token LSQUAREBRACKET "\["
#token RSQUAREBRACKET "\]"

#token LPAREN "\("
#token RPAREN "\)"

// Begin and End

#token BEGIN "begin"
#token END "end"

// Identifiers

// I define that they cannot start with numbers
#token ID "[a-zA-Z_][a-zA-Z0-9_]*"

// Numbers

#token NUMBER "[0-9]+"

// Spaces

#token SPACE "[\ \n]" << zzskip();>>


/* ########################## */
/* ### Production definitions */
/* ########################## */

/* Orientations */

dorientation: TUP | TRIGHT | TDOWN | TLEFT;

/* Boolean queries */

dboolean_query: FOUNDBEEPER | ISCLEAR | ANYBEEPERSINBAG;

dboolean_atom: dboolean_query | NOT^ dboolean_atom 
               | LPAREN! dlogical_expr RPAREN!;

/* Instructions*/

datomic_instruction: (TURNLEFT | MOVE | PUTBEEPER | PICKBEEPER | TURNOFF | ID) 
                     SEMICOLON!;

dlogical_expr: dboolean_atom ((AND^ | OR^) dboolean_atom)*; 

dif: IF^ dlogical_expr LCURLYBRACKET! linstr RCURLYBRACKET!;

diterate: ITERATE^ NUMBER LCURLYBRACKET! linstr RCURLYBRACKET!;

dinstruction: datomic_instruction | dif | diterate;

linstr: (dinstruction)* <<#0=createASTlist(_sibling);>>;

/* Definitions */

// Functions

dfunction: DEFINE^ ID LCURLYBRACKET! linstr RCURLYBRACKET!;

// Walls

dwall: NUMBER NUMBER dorientation;

dwalls: WALLS^ LSQUAREBRACKET! dwall (COMMA! dwall)* RSQUAREBRACKET!;

// Beepers

dbeepers: BEEPERS^ NUMBER NUMBER NUMBER;

ddefinition: dfunction | dwalls | dbeepers; 

/* Global grammar */

dworld: WORLD^ NUMBER NUMBER;

drobot: ROBOT^ NUMBER NUMBER NUMBER dorientation; 

definitions: (ddefinition)* <<#0=createASTlist(_sibling);>>;

karel: dworld drobot definitions BEGIN! linstr END! 
       <<#0=createASTlist(_sibling);>>;
