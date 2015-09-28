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

// # Utils

// Useful to use strings in a switch statement
constexpr unsigned int si(const char* str, int h = 0) {
  return !str[h] ? 5381 : (si(str, h + 1)*33) ^ str[h];
}

// To parse strings to integers
inline int sti(const string& s) { 
	return atoi(s.c_str());
}

// # Orientation

inline Orientation sToOrientation(const string& s) {
	switch (si(s.c_str())) {
		case si("up"): return Orientation::UP;
		case si("right"): return Orientation::RIGHT;
		case si("down"): return Orientation::DOWN;
		case si("left"): return Orientation::LEFT;
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
	this->sizeX = sti(worldNode->down->kind);
	this->sizeY = sti(worldNode->down->right->kind);
}

void World::addBeeper(AST* beeperNode) {
	// TODO: Què s'ha de fer si ja hi és?

	AST* xNode = beeperNode->down;
	AST* yNode = xNode->right;
	AST* amountNode = yNode->right;

	Position position(sti(xNode->kind), sti(yNode->kind));
	int amount = sti(amountNode->kind);

	beepers[position] = amount;
}

void World::addWalls(AST* wallsNode) {
	// TODO: Què s'ha de fer si ja hi són?

	wallsNode = wallsNode->down;

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
	AST* xNode = robotNode->down;
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

void Robot::tryToMove() {
	if (not isOn) return;

	Position destiny = this->pose.nextPosition();

	if (destiny.insideWorld() and this->pose.isClear()) this->pose.advance();
}

// # Evaluation

bool evaluateCondition(AST* a) {
	AST* fc;

	switch (si(a->kind.c_str())) {
		case si("foundBeeper"): return robot.pose.position.hasBeeper();
		case si("isClear"): return robot.pose.isClear();
		case si("anyBeepersInBag"): return robot.beeperCount > 0;

		case si("not"): return not evaluateCondition(child(a, 0));
		case si("and"): fc = child(a, 0); return evaluateCondition(fc) and evaluateCondition(fc->right);
		case si("or"): fc = child(a, 0); return evaluateCondition(fc) or evaluateCondition(fc->right);
	}
}

void evaluateDefinitions(AST* list) {
	AST* currDefinition = list->down;

	while (currDefinition != NULL) {
		switch (si(currDefinition->kind.c_str())) {
			case si("walls"):  world.addWalls(currDefinition); break;
			case si("beepers"): world.addBeeper(currDefinition); break;
			case si("define"): functionDefinitions.add(currDefinition); break;
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
				if (evaluateCondition(currInstruction->down)) evaluateInstructions(currInstruction->down->right);
				break;
			case si("turnleft"): robot.turnLeft(); break;
			case si("move"): robot.tryToMove(); break;
			case si("putbeeper"):
				if (not robot.isOn) break;

				if (robot.beeperCount > 0) {
					--robot.beeperCount;
					world.putBeeper(robot.pose.position);
				}
				else cerr << "Cannot put beeper because robot has no beepers left!" << endl; 
				// TODO: Què passa si no en té?

				break;
			case si("pickbeeper"):
				if (not robot.isOn) break;

				if (world.pickBeeper(robot.pose.position)) ++robot.beeperCount;
				else cerr << "Cannot pick beeper because there's no beeper in the current robot's position!" << endl;
				// TODO: Què passa si a la posició no n'hi ha?

				break;
			case si("id"): evaluateInstructions(functionDefinitions.get(currInstruction->text)); break;
			case si("turnoff"): robot.turnOff(); break;
		}

		advance(currInstruction);
	}
}

// # Main methods

void newPosition(AST* root) {
	AST* worldNode = root->down;
	AST* robotNode = worldNode->right;
	AST* definitionsList = robotNode->right;
	AST* instructionsList = definitionsList->right;
	
	world.initialize(worldNode); 
	robot.initialize(robotNode);
	evaluateDefinitions(definitionsList);
	evaluateInstructions(instructionsList);

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