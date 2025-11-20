#include "register_types.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "litrt_compiled_model.h"
#include "litrt_environment.h"
#include "litrt_model.h"
#include "litrt_tensor_buffer.h"

using namespace godot;

void initialize_litert_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

	ClassDB::register_class<LiteRtEnvironmentRef>();
	ClassDB::register_class<LiteRtModelRef>();
	ClassDB::register_class<LiteRtCompiledModelRef>();
	ClassDB::register_class<LiteRtTensorBufferRef>();
}

void uninitialize_litert_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
// Initialization.
GDExtensionBool GDE_EXPORT godot_litert_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_litert_module);
	init_obj.register_terminator(uninitialize_litert_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}

