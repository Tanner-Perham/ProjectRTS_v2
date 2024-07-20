extends RefCounted

enum MODULES {
    FORMATION
}

const SCRIPTS:Dictionary = {
    MODULES.FORMATION : preload("res://scripts/module_formation.gd"),
}