#include "litrt_model.h"

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/file_access.hpp>

// Include the LiteRT header here to get the typedef
#include <litert/c/litert_model.h>

void LiteRtModelRef::_bind_methods() {
	ClassDB::bind_method(D_METHOD("load_from_file", "path"), &LiteRtModelRef::load_from_file);
	ClassDB::bind_method(D_METHOD("is_valid"), &LiteRtModelRef::is_valid);
	ClassDB::bind_method(D_METHOD("get_num_signatures"), &LiteRtModelRef::get_num_signatures);
}

LiteRtModelRef::LiteRtModelRef() {
}

LiteRtModelRef::~LiteRtModelRef() {
	if (model != nullptr) {
		// Cast handle to typedef type for LiteRT API (both are pointers)
		LiteRtModel handle = reinterpret_cast<LiteRtModel>(model);
		LiteRtDestroyModel(handle);
		model = nullptr;
	}
}

Error LiteRtModelRef::load_from_file(const String &p_path) {
	if (model != nullptr) {
		return ERR_ALREADY_EXISTS;
	}

	Ref<FileAccess> file = FileAccess::open(p_path, FileAccess::READ);
	if (file.is_null()) {
		return ERR_FILE_NOT_FOUND;
	}

	PackedByteArray data = file->get_buffer(file->get_length());
	file.unref();

	if (data.size() == 0) {
		return ERR_INVALID_DATA;
	}

	// Use the typedef type from litert headers for API call
	LiteRtModel handle = nullptr;
	LiteRtStatus status = LiteRtCreateModelFromBuffer(data.ptr(), data.size(), &handle);
	if (status != kLiteRtStatusOk) {
		model = nullptr;
		return FAILED;
	}
	model = reinterpret_cast<LiteRtModelHandle>(handle); // Assign to our handle type

	return OK;
}

int LiteRtModelRef::get_num_signatures() const {
	if (model == nullptr) {
		return 0;
	}

	// Cast handle to typedef type for LiteRT API (both are pointers)
	LiteRtModel handle = reinterpret_cast<LiteRtModel>(model);
	LiteRtParamIndex num_signatures = 0;
	LiteRtStatus status = LiteRtGetNumModelSignatures(handle, &num_signatures);
	if (status != kLiteRtStatusOk) {
		return 0;
	}

	return static_cast<int>(num_signatures);
}

