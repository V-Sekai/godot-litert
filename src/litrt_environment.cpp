#include "litrt_environment.h"

#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/core/class_db.hpp>

// Include the LiteRT header here to get the typedef
#include <litert/c/litert_environment.h>

void LiteRtEnvironmentRef::_bind_methods() {
	ClassDB::bind_method(D_METHOD("create"), &LiteRtEnvironmentRef::create);
	ClassDB::bind_method(D_METHOD("is_valid"), &LiteRtEnvironmentRef::is_valid);
}

LiteRtEnvironmentRef::LiteRtEnvironmentRef() {
}

LiteRtEnvironmentRef::~LiteRtEnvironmentRef() {
	if (environment != nullptr) {
		// Cast handle to typedef type for LiteRT API (both are pointers)
		LiteRtEnvironment handle = reinterpret_cast<LiteRtEnvironment>(environment);
		LiteRtDestroyEnvironment(handle);
		environment = nullptr;
	}
}

Error LiteRtEnvironmentRef::create() {
	if (environment != nullptr) {
		return ERR_ALREADY_EXISTS;
	}

	// Use the typedef type from litert headers for API call
	LiteRtEnvironment handle = nullptr;
	LiteRtStatus status = LiteRtCreateEnvironment(0, nullptr, &handle);
	if (status != kLiteRtStatusOk) {
		environment = nullptr;
		return FAILED;
	}
	environment = reinterpret_cast<LiteRtEnvironmentHandle>(handle); // Assign to our handle type

	return OK;
}

