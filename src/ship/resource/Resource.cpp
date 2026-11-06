#include "ship/resource/Resource.h"
#include <spdlog/spdlog.h>

namespace Ship {
IResource::IResource(std::shared_ptr<ResourceInitData> initData) : mInitData(initData) {
}

IResource::~IResource() {
    if (const auto initData = GetInitData()) {
        SPDLOG_TRACE("Resource Unloaded: {}\n", initData->Path);
    }
}

bool IResource::IsDirty() {
    return mIsDirty;
}

void IResource::Dirty() {
    mIsDirty = true;
}

std::shared_ptr<ResourceInitData> IResource::GetInitData() {
    return mInitData;
}
} // namespace Ship
