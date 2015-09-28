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

// DEBUG
void print_world();
#include <array>
#include <cassert>
#include <unistd.h>
#define ASR_ERROR(txt) cerr << txt << endl; assert(false)

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
	}
}




/* ####################################### */
/* ## A S T    I N T E R P R E T A T I O N */
/* ####################################### */

/* ############################## */
/* ### Data structures definition */
/* ############################## */


// # Orientation
enum class Orientation { UP, RIGHT, DOWN, LEFT };

ostream& operator<<(ostream& s, const Orientation& orientation) {
	switch (orientation) {
		case Orientation::UP: s << "up"; break;
		case Orientation::RIGHT: s << "right"; break;
		case Orientation::DOWN: s << "down"; break;
		case Orientation::LEFT: s << "left"; break;
	}
	return s;
}

// # Position
struct Position {
	int i, j;

	// TODO: S'ha de comprovar que les posicions siguin correctes?
	Position() {}
	Position(int i, int j) : i(i), j(j) {} 
	Position(const Position& p) : i(p.i), j(p.j) {}

	bool insideWorld() const;
	bool hasBeeper() const;

	inline bool operator==(const Position& other) const {
		return other.i == i and other.j == j;
	}

	friend ostream& operator<<(ostream& s, const Position& position) {
		s << position.i << ' ' << position.j;
		return s;
	}

	inline Position& operator+=(const Orientation& orientation) {
		switch (orientation) {
			case Orientation::UP: --i; break;
			case Orientation::RIGHT: ++j; break;
			case Orientation::DOWN: ++i; break;
			case Orientation::LEFT: --j; break;
			default: ASR_ERROR("Invalid orientation"); // DEBUG
		}

		return *this;
	}

	inline Position operator+(const Orientation& orientation) const {
		Position res(*this);
		return res += orientation; 
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

	friend ostream& operator<<(ostream& s, const Pose& pose) {
		s << pose.position << ' ' << pose.orientation;
		return s;
	}
};
// Hashing function definitions for Position and Pose
template <class T> inline void hash_combine(size_t& seed, const T& v) {
	hash<T> hasher; seed ^= hasher(v) + 0x9e3779b9 + (seed/*<<6*/*64) + (seed/*>>2*//4); 
}
namespace std {
	template <> struct hash<Position> {
		size_t operator()(const Position& position) const {
			size_t seed = 0;
			hash_combine(seed, position.i); 
			hash_combine(seed, position.j);
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
	static const int COORD_ORIGIN = 1; // Min value for i and j coords

	int sizeI, sizeJ;

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
	void tryToMove();
};

// # Function definitions
class FunctionDefinitions { // Implements finding function definitions in O(1) average
	private:
		unordered_map<string, AST*> map;

	public:
		inline void add(AST* definition) {
			// TODO: Què s'ha de fer si ja està definida?
			string id = definition->down->text;
			AST* insList = definition->down->right;
			map[id] = insList;
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

// Useful to use strings in a switch statement
constexpr unsigned int si(const char* str, int h = 0) {
  return !str[h] ? 5381 : (si(str, h + 1)*33) ^ str[h];
}

inline Orientation sToOrientation(const string& s) {
	switch (si(s.c_str())) {
		case si("up"): return Orientation::UP;
		case si("right"): return Orientation::RIGHT;
		case si("down"): return Orientation::DOWN;
		case si("left"): return Orientation::LEFT;
		default: ASR_ERROR("Invalid orientation"); // DEBUG
	}
}

// To parse strings to integers
inline int sti(const string& s) { 
	return atoi(s.c_str());
}

inline AST* advance(AST*& a) {
	return a = a->right;
}

bool Position::insideWorld() const {
	return (World::COORD_ORIGIN <= this->i and this->i <= world.sizeI) 
			and 
		   (World::COORD_ORIGIN <= this->j and this->j <= world.sizeJ);
}

bool Position::hasBeeper() const {
	auto it = world.beepers.find(*this);
	return it != world.beepers.end() and it->second > 0; 
}

Orientation opposite(Orientation o) {
	switch(o) {
		case Orientation::LEFT: return Orientation::RIGHT;
		case Orientation::RIGHT: return Orientation::LEFT;
		case Orientation::UP: return Orientation::DOWN;
		case Orientation::DOWN: return Orientation::UP;
	}
}

Pose equivalentWall(const Pose& wall) {
	return Pose(wall.position + wall.orientation, opposite(wall.orientation));
}

// PRE: this->position.insideWorld() is true
bool Pose::isClear() const {
	return world.walls.find(*this) == world.walls.end() and world.walls.find(equivalentWall(*this)) == world.walls.end();
}

void World::initialize(AST* worldNode) {
	this->sizeI = sti(worldNode->down->kind);
	this->sizeJ = sti(worldNode->down->right->kind);
}

void Robot::initialize(AST* robotNode) {
	AST* iNode = robotNode->down;
	AST* jNode = iNode->right;
	AST* beeperCountNode = jNode->right;
	AST* orientationNode = beeperCountNode->right;

	this->pose.position.i = sti(iNode->kind);
	this->pose.position.j = sti(jNode->kind);
	this->beeperCount = sti(beeperCountNode->kind);
	this->pose.orientation = sToOrientation(orientationNode->kind);
	
	this->isOn = true;
}

void World::putBeeper(const Position& position) {
	auto it = this->beepers.find(position);

	if (it == this->beepers.end()) this->beepers.insert(it, make_pair(position, 1));
	else ++it->second;
}

bool World::pickBeeper(const Position& position) {
	auto it = this->beepers.find(position);

	bool picked = it != this->beepers.end() and it->second > 0;
	if (picked) --it->second;

	return picked;
}

void World::addBeeper(AST* beeperNode) {
	// TODO: Què s'ha de fer si ja hi és?

	AST* iNode = beeperNode->down;
	AST* jNode = iNode->right;
	AST* amountNode = jNode->right;

	Position position(sti(iNode->kind), sti(jNode->kind));
	int amount = sti(amountNode->kind);

	beepers[position] = amount;
}

void World::addWalls(AST* wallsNode) {
	// TODO: Què s'ha de fer si ja hi són?

	wallsNode = wallsNode->down;

	while (wallsNode != NULL) {
		AST* iNode = wallsNode;
		AST* jNode = advance(wallsNode);
		AST* orientationNode = advance(wallsNode);

		Position position(sti(iNode->kind), sti(jNode->kind));
		Pose pose(position, sToOrientation(orientationNode->kind));

		this->walls.insert(pose);

		advance(wallsNode);
	}
}

Orientation randOrientation() {
	switch(rand()%4) {
		case 0: return Orientation::LEFT;
		case 1: return Orientation::RIGHT;
		case 2: return Orientation::UP;
		case 3: return Orientation::DOWN;
	}
}

void Robot::turnLeft() {
	if (not isOn) return;

	switch (this->pose.orientation) {
		case Orientation::UP: this->pose.orientation = Orientation::LEFT; break;
		case Orientation::RIGHT: this->pose.orientation = Orientation::UP; break;
		case Orientation::DOWN: this->pose.orientation = Orientation::RIGHT; break;
		case Orientation::LEFT: this->pose.orientation = Orientation::DOWN; break;
		default: ASR_ERROR("Invalid orientation"); // DEBUG
	}
}

void Robot::tryToMove() {
	if (not isOn) return;

	Position destiny = this->pose.nextPosition();

	if (destiny.insideWorld() and this->pose.isClear()) this->pose.advance();
}

bool evaluateCondition(AST* a) {
	AST* fc;

	switch (si(a->kind.c_str())) {
		case si("foundBeeper"):
			return robot.pose.position.hasBeeper();
		case si("isClear"):
			return robot.pose.isClear();
		case si("anyBeepersInBag"):
			return robot.beeperCount > 0;

		case si("not"): fc = a->down;
			return not evaluateCondition(fc);
		case si("and"): fc = a->down;
			return evaluateCondition(fc) and evaluateCondition(fc->right);
		case si("or"): fc = a->down;
			return evaluateCondition(fc) or evaluateCondition(fc->right);
		default: ASR_ERROR("Invalid condition"); // DEBUG
	}
}

void evaluateDefinitions(AST* list) {
	AST* currDefinition = list->down;

	while (currDefinition != NULL) {
		switch (si(currDefinition->kind.c_str())) {
			case si("walls"):  world.addWalls(currDefinition); break;
			case si("beepers"): world.addBeeper(currDefinition); break;
			case si("define"): functionDefinitions.add(currDefinition); break;
			default: ASR_ERROR("Invalid definition"); // DEBUG
		}

		advance(currDefinition);
	}
}

void evaluateInstructions(AST* list) {
	AST* currInstruction = list->down;

	while (currInstruction != NULL) {
		int times;

		switch(si(currInstruction->kind.c_str())) {
			case si("iterate"):
				times = sti(currInstruction->down->kind);
				while (times--) evaluateInstructions(currInstruction->down->right);
				break;
			case si("if"):
				if (evaluateCondition(currInstruction->down)) 
					evaluateInstructions(currInstruction->down->right);
				break;
			case si("turnleft"): 
				robot.turnLeft(); 
				print_world(); // DEBUG
				break;
			case si("move"): 
				robot.tryToMove(); 
				print_world(); // DEBUG
			break;
			case si("putbeeper"):
				if (not robot.isOn) break;

				if (robot.beeperCount > 0) {
					--robot.beeperCount;
					world.putBeeper(robot.pose.position);
				}
				else cerr << "Cannot put beeper because robot has no beepers left!" << endl; 
				// TODO: Què passa si no en té?

				print_world(); // DEBUG
				break;
			case si("pickbeeper"):
				if (not robot.isOn) break;

				if (world.pickBeeper(robot.pose.position)) ++robot.beeperCount;
				else cerr << "Cannot pick beeper because there's no beeper in the current robot's position!" << endl;
				// TODO: Què passa si a la posició no n'hi ha?
				print_world(); // DEBUG
				break;
			case si("id"): evaluateInstructions(functionDefinitions.get(currInstruction->text)); break;
			case si("turnoff"): 
				robot.turnOff(); 
				print_world(); // DEBUG
				break;
			default: ASR_ERROR("Invalid instruction"); // DEBUG
		}

		advance(currInstruction);
	}
}


// DEBUG
#define PNT(cnd, chr, style) if (cnd) cout << style << chr << normal; else cout << ' ';
#define PNTW(cnd) if (cnd) cout << w_st << WALL << normal; else cout << WALL;
#define IN(val, cont) cont.find((val)) != cont.end()

char robot_char() {
	switch (robot.pose.orientation) {
		case Orientation::LEFT: return '<';
		case Orientation::RIGHT: return '>';
		case Orientation::UP: return '^';
		case Orientation::DOWN: return 'V';
	}
}


char r_st[] = { 0x1b, '[', '1', ';', '3', '6', 'm', 0 };
char s_st[] = { 0x1b, '[', '1', ';', '3', '5', 'm', 0 };
char w_st[] = { 0x1b, '[', '1', ';', '3', '7', 'm', 0 };
char back_st[] = { 0x1b, '[', '0', ';', '4', '0', 'm', 0 };
char b_normal[] = { 0x1b, '[', '1', ';', '4', '9', 'm', 0 };
char normal[] = { 0x1b, '[', '1', ';', '3', '0', 'm', 0 };
char default_st[] = { 0x1b, '[', '1', ';', '3', '9', 'm', 0 };

void print_cell_elem(int row, int col, int i, int j, bool fuckingCorner = false) {
	const string cellFormat[] = {
		"WTTTO",
		"LUXSR",
		"YBBBV"
   	};

   	Position position(i, j);

   	bool leftWall = not Pose(position, sToOrientation("left")).isClear();
   	bool rightWall = not Pose(position, sToOrientation("right")).isClear();
   	bool upWall = not Pose(position, sToOrientation("up")).isClear();
   	bool downWall = not Pose(position, sToOrientation("down")).isClear();
   	bool thereIsRobot = robot.pose.position == position;

   	bool isFuckedUpCorner = fuckingCorner and not Pose(position + Orientation::UP, Orientation::LEFT).isClear(); 

   	auto it = world.beepers.find(position);
   	int sensors = it == world.beepers.end() ? 0 : it->second;

    // W = Left or Top
    // L = Left
    // Y = Left or Bottom
    // B = Bottom
    // T = Top
    // O = Top or Right
    // R = Right
    // V = Bottom or Right
    // X = Robot or Sensors when both do not appear
    // U = Robot
    // S = Sensors count
    // # = Cell delimiter

    //XXXXXXXXXXXXX
    //X> 9X   X   X
    //XXXXXXXXXXXXX
    //X   X   X   X
    //XXXXXXXXXXXXX
    //X   X   X   X
    //XXXXXXXXXXXXX

    const char WALL = '#';

   	switch(cellFormat[row][col]) {
   		case 'W': PNTW(leftWall or upWall or isFuckedUpCorner); break;
   		case 'L': PNTW(leftWall); break;
   		case 'Y': PNTW(leftWall or downWall); break;
   		case 'B': PNTW(downWall); break;;
   		case 'T': PNTW(upWall); break;
   		case 'O': PNTW(upWall or rightWall or isFuckedUpCorner); break;
   		case 'R': PNTW(rightWall); break;
   		case 'V': PNTW(downWall or rightWall); break;
   		case 'X': 
   			if (thereIsRobot != sensors > 0) {
   				if (thereIsRobot) cout << r_st << robot_char() << normal;
   				else cout << s_st << sensors%10 << normal;
   			}
   			else cout << ' ';
   			break;
   		break;
   		case 'U': PNT(thereIsRobot and sensors, robot_char(), r_st); break;
   		case 'S': PNT(thereIsRobot and sensors, char(sensors%10 + '0'), s_st); break;
   		default: ASR_ERROR("Invalid char");
   	}
}

// DEBUG
void print_world() {
   	const int N_ROWS = 2;
   	const int N_COLS = 4;

   	const int FRAME_RATE_PER_SEC = 10;

   	cout << endl << back_st << normal;

	for (int i = 1; i <= world.sizeI; ++i) {
		for (int row = 0; row < N_ROWS; ++row) {
			for (int j = 1; j <= world.sizeJ; ++j) {
				for (int col = 0; col < N_COLS; ++col) print_cell_elem(row, col, i, j, row == 0 and col == 0);
			}
			print_cell_elem(row, N_COLS, i, world.sizeJ);
			cout << endl;
		}
	}

	for (int i = 0; i < N_COLS*world.sizeJ + 1; ++i) print_cell_elem(N_ROWS, i%N_COLS, world.sizeI, i/N_COLS + 1);

	cout << endl << b_normal << default_st << "Robot: " << (robot.isOn ? "ON, " : "OFF, ") << robot.beeperCount << " beepers" << endl;

	usleep(1000000/FRAME_RATE_PER_SEC);
}

void newPosition(AST* root) {
	AST* worldNode = root->down;
	AST* robotNode = worldNode->right;
	AST* definitionsList = robotNode->right;
	AST* instructionsList = definitionsList->right;
	
	world.initialize(worldNode); 
	robot.initialize(robotNode);

	evaluateDefinitions(definitionsList);

	//print_world();

	evaluateInstructions(instructionsList);

	//print_world();
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