#ifndef LITRT_MODEL_H
#define LITRT_MODEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/binder_common.hpp>

using namespace godot;

// Forward declare to avoid conflict with typedef LiteRtModel (which is LiteRtModelT*)
// Don't include litert_model.h here to avoid typedef conflict
// The typedef will be handled in the .cpp file
class LiteRtModelT;
typedef class LiteRtModelT* LiteRtModelHandle;

class LiteRtModelRef : public RefCounted {
	GDCLASS(LiteRtModelRef, RefCounted);

	// Use opaque pointer to avoid name collision with typedef LiteRtModel
	LiteRtModelHandle model = nullptr;

protected:
	static void _bind_methods();

public:
	LiteRtModelRef();
	~LiteRtModelRef();

	// Load model from file path
	Error load_from_file(const String &p_path);

	// Get the underlying handle
	LiteRtModelHandle get_handle() const { return model; }

	// Check if model is valid
	bool is_valid() const { return model != nullptr; }

	// Get number of signatures
	int get_num_signatures() const;
};

#endif // LITRT_MODEL_H

