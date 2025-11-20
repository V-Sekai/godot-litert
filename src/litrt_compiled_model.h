#ifndef LITRT_COMPILED_MODEL_H
#define LITRT_COMPILED_MODEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/typed_array.hpp>

using namespace godot;

// Forward declare to avoid conflict with typedefs
// Include our headers (which forward declare types, not LiteRT headers)
#include "litrt_tensor_buffer.h"
#include "litrt_environment.h"
#include "litrt_model.h"

// Don't include litert headers here to avoid typedef conflicts
// The typedef will be handled in the .cpp file
// Forward declare to avoid conflict with typedef LiteRtCompiledModel (which is LiteRtCompiledModelT*)
// Note: Our class name conflicts with the LiteRT typedef, so we use a handle type
class LiteRtCompiledModelT;
typedef class LiteRtCompiledModelT* LiteRtCompiledModelHandle;

class LiteRtCompiledModelRef : public RefCounted {
	GDCLASS(LiteRtCompiledModelRef, RefCounted);

	// Use opaque pointer to avoid name collision with typedef LiteRtCompiledModel
	LiteRtCompiledModelHandle compiled_model = nullptr;
	Ref<LiteRtEnvironmentRef> environment;
	Ref<LiteRtModelRef> model;

protected:
	static void _bind_methods();

public:
	LiteRtCompiledModelRef();
	~LiteRtCompiledModelRef();

	// Create compiled model from environment and model
	Error create(Ref<LiteRtEnvironmentRef> p_environment, Ref<LiteRtModelRef> p_model);

	// Run inference
	Error run(int p_signature_index, const TypedArray<LiteRtTensorBufferRef> &p_inputs, TypedArray<LiteRtTensorBufferRef> p_outputs);

	// Get the underlying handle
	LiteRtCompiledModelHandle get_handle() const { return compiled_model; }

	// Check if compiled model is valid
	bool is_valid() const { return compiled_model != nullptr; }

	// Get number of input buffers required
	int get_num_inputs(int p_signature_index) const;

	// Get number of output buffers required
	int get_num_outputs(int p_signature_index) const;
};

#endif // LITRT_COMPILED_MODEL_H

