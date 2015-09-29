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
#include <cmath>
#include <unordered_set>
#include <unordered_map>

#include <cassert>
#include <unistd.h>

#define ERROR(string) cerr << string << endl; assert(false);

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
		ASTPrintIndent(i, s + "  |" + string(i->kind.size() + i->text.size(), ' '));
		i = i->right;
	}

	if (i != NULL) {
		cout << s + "  \\__";
		ASTPrintIndent(i, s + "   " + string(i->kind.size() + i->text.size(), ' '));
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

	// TODO: S'ha de comprovar que les posicions siguin correctes?
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
		return other.position == position and other.orientation == orientation;
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
class FunctionDefinitions { // Implements finding function definitions in O(1) average
	private:
		unordered_map<string, AST*> map;

	public:
		inline void add(AST* definition) {
			// TODO: Què s'ha de fer si ja està definida?
			string id = definition->text;
			AST* insList = definition->right;
			map[id] = child(insList, 0);
		}

		inline AST* get(const string& id) const {
			auto it = map.find(id);

			if (it == map.end()) {
				cerr << "!!DEFINITION NOT FOUND: " << id << " " << endl;
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
		default: ERROR("Invalid orientation string");
	}
}

inline Orientation opposite(Orientation o) {
	switch(o) {
		case Orientation::LEFT: return Orientation::RIGHT;
		case Orientation::RIGHT: return Orientation::LEFT;
		case Orientation::UP: return Orientation::DOWN;
		case Orientation::DOWN: return Orientation::UP;
		default: ERROR("Orientation case missing");
	}
}

// # Position

inline bool Position::insideWorld() const {
	return 0 <= this->x and this->x <= world.sizeX 
			and 
		   0 <= this->y and this->y <= world.sizeY;
}

inline bool Position::hasBeeper() const {
	auto it = world.beepers.find(*this);
	return it != world.beepers.end() and it->second > 0; 
}

// # Pose

inline Pose equivalentWall(const Pose& wall) {
	return Pose(wall.position + wall.orientation, opposite(wall.orientation));
}

// TODO: Does this need to check that the position being checked is inside the world?
// TODO: Is this supposed to check both equivalent walls?
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
	// TODO: Què s'ha de fer si ja hi és?

	AST* xNode = beeperNode;
	AST* yNode = xNode->right;
	AST* amountNode = yNode->right;

	Position position(sti(xNode->kind), sti(yNode->kind));
	int amount = sti(amountNode->kind);

	beepers[position] = amount;
}

void World::addWalls(AST* wallsNode) {
	// TODO: Què s'ha de fer si ja hi són?

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

	if (it == this->beepers.end()) this->beepers.insert(it, make_pair(position, 1));
	else ++it->second;
}

bool World::pickBeeper(const Position& position) {
	// TODO: Què s'ha de fer si no hi ha beeper?

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

	switch (this->pose.orientation) {
		case Orientation::UP: this->pose.orientation = Orientation::LEFT; break;
		case Orientation::RIGHT: this->pose.orientation = Orientation::UP; break;
		case Orientation::DOWN: this->pose.orientation = Orientation::RIGHT; break;
		case Orientation::LEFT: this->pose.orientation = Orientation::DOWN; break;
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
	else cerr << "Cannot pick beeper because there's no beeper in the current robot's position!" << endl;
	// TODO: Què passa si a la posició no n'hi ha?
}

void Robot::putBeeper() {
	if (not isOn) return;

	if (beeperCount > 0) {
		--beeperCount;
		world.putBeeper(pose.position);
	}
	else cerr << "Cannot put beeper because robot has no beepers left!" << endl; 
	// TODO: Què passa si no en té?
}

bool Robot::foundBeeper() {
	// TODO: Ha de retornar cert si el robot està apagat?
	return pose.position.hasBeeper();
}

// # Debugging

class Debugger {
	private:
		const char WALL = '#';
		const char NOTHING = ' ';

		const char ROBOT_LEFT = '<';
		const char ROBOT_RIGHT = '>';
		const char ROBOT_UP = '^';
		const char ROBOT_DOWN = 'V';

		const char wallStyle[8] = { 0x1b, '[', '1', ';', '3', '7', 'm', 0 };
		const char robotStyle[8] = { 0x1b, '[', '1', ';', '3', '6', 'm', 0 };
		const char sensorStyle[8] = { 0x1b, '[', '1', ';', '3', '5', 'm', 0 };
		const char backgroundStyle[8] = { 0x1b, '[', '0', ';', '4', '0', 'm', 0 };
		const char backgroundNormal[8] = { 0x1b, '[', '1', ';', '4', '9', 'm', 0 };
		const char normalStyle[8] = { 0x1b, '[', '1', ';', '3', '9', 'm', 0 };
		const char defaultCellStyle[8] = { 0x1b, '[', '1', ';', '3', '0', 'm', 0 };

		const string cellFormat[3] = {
			"WTTTO",
			"LUXSR",
			"YBBBV"
   		};

   		const int N_ROWS = 2;
		const int N_COLS = 4;

		const int FRAME_RATE_PER_SEC = 8;

		void printWithStyle(bool condition, char c, const char style[]) {
			if (condition) cout << style << c << defaultCellStyle;
			else cout << NOTHING;
		}

		void printWall(bool condition) {
			if (condition) cout << wallStyle << WALL << defaultCellStyle;
			else cout << WALL;
		}

		void printIfNotRobotAndSensors(bool thereIsRobot, int sensors) {
			if (thereIsRobot != sensors > 0) {
	   			if (thereIsRobot) cout << robotStyle << robotChar() << defaultCellStyle;
	   			else cout << sensorStyle << sensors%10 << defaultCellStyle;
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

		void printCellElem(int row, int col, int x, int y, bool fuckingCorner = false) {
			Position position(x, y);

		   	bool leftWall = not Pose(position, Orientation::LEFT).isClear();
		   	bool rightWall = not Pose(position, Orientation::RIGHT).isClear();
		   	bool upWall = not Pose(position, Orientation::UP).isClear();
		   	bool downWall = not Pose(position, Orientation::DOWN).isClear();

		   	bool thereIsRobot = robot.pose.position == position;

		   	bool isFuckedUpCorner = fuckingCorner and not Pose(position + Orientation::UP, Orientation::LEFT).isClear(); 

		   	auto it = world.beepers.find(position);
		   	int sensors = it == world.beepers.end() ? 0 : it->second;

		   	switch(cellFormat[row][col]) {
		   		case 'W': printWall(leftWall or upWall or isFuckedUpCorner); break;
		   		case 'L': printWall(leftWall); break;
		   		case 'Y': printWall(leftWall or downWall); break;
		   		case 'B': printWall(downWall); break;;
		   		case 'T': printWall(upWall); break;
		   		case 'O': printWall(upWall or rightWall or isFuckedUpCorner); break;
		   		case 'R': printWall(rightWall); break;
		   		case 'V': printWall(downWall or rightWall); break;
		   		case 'X': printIfNotRobotAndSensors(thereIsRobot, sensors); break;
		   		case 'U': printWithStyle(thereIsRobot and sensors, robotChar(), robotStyle); break;
		   		case 'S': printWithStyle(thereIsRobot and sensors, char(sensors%10 + '0'), sensorStyle); break;
		   		default: ERROR("Invalid cell format character");
		   	}
		}

	public:

		void printWorld() {
		   	cout << endl << backgroundStyle << defaultCellStyle;

			for (int y = 0; y < world.sizeY; ++y) {
				for (int row = 0; row < N_ROWS; ++row) {
					for (int x = 0; x < world.sizeX; ++x) {
						for (int col = 0; col < N_COLS; ++col) printCellElem(row, col, x, y, row == 0 and col == 0);
					}
					printCellElem(row, N_COLS, world.sizeX, y);
					cout << endl;
				}
			}

			for (int i = 0; i < N_COLS*world.sizeX + 1; ++i) printCellElem(N_ROWS, i%N_COLS, i/N_COLS, world.sizeY);

			cout << endl << backgroundNormal << normalStyle << "Robot: " << (robot.isOn ? "ON, " : "OFF, ") << robot.beeperCount << " beepers" << endl;

			usleep(1000000/FRAME_RATE_PER_SEC);
		}
};

Debugger debugger;

// # Evaluation

bool evaluateCondition(AST* a) {
	AST* fc;

	if (a->kind == "foundBeeper") return robot.foundBeeper();
	else if (a->kind == "isClear") return robot.pose.isClear();
	else if (a->kind == "anyBeepersInBag") return robot.beeperCount > 0;
	else if (a->kind == "not") return not evaluateCondition(child(a, 0));
	else if (a->kind == "and") {
		fc = child(a, 0); 
		return evaluateCondition(fc) and evaluateCondition(fc->right);
	}
	else if (a->kind == "or") {
		fc = child(a, 0);
		return evaluateCondition(fc) or evaluateCondition(fc->right);	
	}
	else ERROR("Invalid condition");
}

void evaluateDefinitions(AST* def) {
	while (def != NULL) {
		if (def->kind == "walls") world.addWalls(child(def, 0));
		else if (def->kind == "beepers") world.addBeeper(child(def, 0));
		else if (def->kind == "define") functionDefinitions.add(child(def, 0));
		else ERROR("Invalid definition");

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
	if (evaluateCondition(_if)) evaluateInstructions(child(_if->right, 0));
}

void evaluateInstructions(AST* instr) {
	debugger.printWorld();

	while (instr != NULL) {
		if (instr->kind == "iterate") evaluateIterate(child(instr, 0));
		else if (instr->kind == "if") evaluateIf(child(instr, 0));
		else if (instr->kind == "turnleft") robot.turnLeft();
		else if (instr->kind == "move") robot.move();
		else if (instr->kind == "putbeeper") robot.putBeeper();
		else if (instr->kind == "pickbeeper") robot.pickBeeper();
		else if (instr->kind == "id") evaluateInstructions(functionDefinitions.get(instr->text)); 
		else if (instr->kind == "turnoff") robot.turnOff();
		else ERROR("Invalid instruction");

		advance(instr);
	}
}

// # Main methods

void newPosition(AST* root) {
	AST* worldNode = child(root, 0);
	AST* robotNode = worldNode->right;
	AST* definitionsList = robotNode->right;
	AST* instructionsList = definitionsList->right;
	
	world.initialize(child(worldNode, 0)); 
	robot.initialize(child(robotNode, 0));

	evaluateDefinitions(child(definitionsList, 0));
	
	debugger.printWorld();

	evaluateInstructions(child(instructionsList, 0));

	cout << robot.pose.position << endl;
}

int main() {
	AST* root = NULL;
	
	ANTLR(karel(&root), stdin);

	ASTPrint(root);
	
	newPosition(root); 
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

#token ID "[a-zA-Z_][a-zA-Z0-9_]*" // I define that they cannot start with numbers

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

dboolean_atom: dboolean_query | NOT^ dboolean_atom | LPAREN! dlogical_expr RPAREN!;

/* Instructions*/

datomic_instruction: (TURNLEFT | MOVE | PUTBEEPER | PICKBEEPER | TURNOFF | ID) SEMICOLON!;

dlogical_expr: dboolean_atom ((AND^ | OR^) dlogical_expr | ); 

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

karel: dworld drobot definitions BEGIN! linstr END! <<#0=createASTlist(_sibling);>>;