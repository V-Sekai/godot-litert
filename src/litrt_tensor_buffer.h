#ifndef LITRT_TENSOR_BUFFER_H
#define LITRT_TENSOR_BUFFER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/typed_array.hpp>

using namespace godot;

// Forward declare to avoid conflict with typedef LiteRtTensorBuffer (which is LiteRtTensorBufferT*)
// Don't include litert_tensor_buffer.h here to avoid typedef conflict
// The typedef will be handled in the .cpp file
class LiteRtTensorBufferT;
typedef class LiteRtTensorBufferT* LiteRtTensorBufferHandle;

class LiteRtTensorBufferRef : public RefCounted {
	GDCLASS(LiteRtTensorBufferRef, RefCounted);

	// Use opaque pointer to avoid name collision with typedef LiteRtTensorBuffer
	LiteRtTensorBufferHandle tensor_buffer = nullptr;
	PackedFloat32Array data_array;
	void *host_memory = nullptr;

protected:
	static void _bind_methods();

public:
	LiteRtTensorBufferRef();
	~LiteRtTensorBufferRef();

	// Create tensor buffer from PackedFloat32Array
	Error create_from_array(const PackedFloat32Array &p_data, const PackedInt32Array &p_shape);

	// Get data as PackedFloat32Array
	PackedFloat32Array get_data() const;

	// Get the underlying handle
	LiteRtTensorBufferHandle get_handle() const { return tensor_buffer; }

	// Check if tensor buffer is valid
	bool is_valid() const { return tensor_buffer != nullptr; }

	// Get shape
	PackedInt32Array get_shape() const;
};

#endif // LITRT_TENSOR_BUFFER_H

