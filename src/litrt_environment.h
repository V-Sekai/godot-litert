#ifndef LITRT_ENVIRONMENT_H
#define LITRT_ENVIRONMENT_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>

using namespace godot;

// Forward declare to avoid conflict with typedef LiteRtEnvironment (which is LiteRtEnvironmentT*)
// Don't include litert_environment.h here to avoid typedef conflict
// The typedef will be handled in the .cpp file
class LiteRtEnvironmentT;
typedef class LiteRtEnvironmentT* LiteRtEnvironmentHandle;

class LiteRtEnvironmentRef : public RefCounted {
	GDCLASS(LiteRtEnvironmentRef, RefCounted);

	// Use opaque pointer to avoid name collision with typedef LiteRtEnvironment
	LiteRtEnvironmentHandle environment = nullptr;

protected:
	static void _bind_methods();

public:
	LiteRtEnvironmentRef();
	~LiteRtEnvironmentRef();

	// Create environment (can be called with optional options)
	Error create();

	// Get the underlying handle
	LiteRtEnvironmentHandle get_handle() const { return environment; }

	// Check if environment is valid
	bool is_valid() const { return environment != nullptr; }
};

#endif // LITRT_ENVIRONMENT_H

