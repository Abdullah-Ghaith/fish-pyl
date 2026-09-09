class_name SkillTree extends RefCounted
## Namespace for the addon's shared enums. Never instantiated - it exists so
## SkillTreeStyle and SkillTreeState can both name the same states without
## depending on each other.

enum NodeState {
	LOCKED,     ## Prerequisites not met.
	GATED,      ## Prerequisites met, but a connection's lock is still closed.
	AVAILABLE,  ## Buyable (affordability is separate - see State.can_afford).
	PURCHASED,  ## Owned, and has ranks left to buy.
	MAXED,      ## Owned at max rank.
}

## How a node treats several incoming connections.
enum Requirement {
	ALL,  ## Every incoming connection must be satisfied.
	ANY,  ## One satisfied connection is enough.
}
