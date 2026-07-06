%rename (InstantCamera) Pylon::CInstantCamera;

%ignore IInstantCameraExtensions;
%ignore GetExtensionInterface;
%ignore CGrabResultDataFactory;
%ignore CreateDeviceSpecificGrabResultData;
%ignore CreateGrabResultData;
%ignore CInstantCameraParams_Params;
%ignore Basler_InstantCameraParams;

namespace Basler_InstantCameraParams
{
   class CInstantCameraParams_Params
   {
   };
}
namespace Pylon
{
   using namespace Basler_InstantCameraParams;
}

#define AutoLock GENAPI_NAMESPACE::AutoLock
#define CLock GENAPI_NAMESPACE::CLock

%rename(ConfigurationEventHandler) Pylon::CConfigurationEventHandler;
%rename(ImageEventHandler) Pylon::CImageEventHandler;
%rename(CameraEventHandler) Pylon::CCameraEventHandler;
%rename(StartGrabbingMax) StartGrabbing( size_t maxImages, EGrabStrategy strategy = GrabStrategy_OneByOne, EGrabLoop grabLoopType = GrabLoop_ProvidedByUser);

namespace Pylon {
     class CConfigurationEventHandler;
     class CImageEventHandler;
     class CCameraEventHandler;
};

%pythoncode %{
    FirstFound = True
    Unambiguous = False
    BufferHandlingMode_Pool = "Pool"
    BufferHandlingMode_Stream = "Stream"
%}

%extend Pylon::CInstantCamera {

    PROP_GET(QueuedBufferCount)
    PROP_GETSET(CameraContext)
    PROP_GET(DeviceInfo)

    PROP_GET(NodeMap)
    PROP_GET(TLNodeMap)
    PROP_GET(StreamGrabberNodeMap)
    PROP_GET(EventGrabberNodeMap)
    PROP_GET(InstantCameraNodeMap)
%pythoncode %{
    StreamGrabber = property(lambda self: self.GetStreamGrabberNodeMap() if self.IsOpen() else None)
    EventGrabber = property(lambda self: self.GetEventGrabberNodeMap() if self.IsOpen() else None)
    TransportLayer = property(lambda self: self.GetTLNodeMap())

    @staticmethod
    def _device_info_from_dict(d):
        di = DeviceInfo()
        di.update(d)
        return di

    def __getattr__(self, attribute):
        if attribute in ( "thisown","this") or attribute.startswith("__"):
            return object.__getattr__(self, attribute)
        else:
            return _LookupParameter(self.GetInstantCameraNodeMap(), self.GetNodeMap() if self.IsPylonDeviceAttached() else None, attribute)

    def __setattr__(self, attribute, val):
        if attribute in ( "thisown","this") or attribute.startswith("__"):
            object.__setattr__(self, attribute, val)
        else:
            type_attr = getattr(type(self), attribute, None)
            if isinstance(type_attr, property):
                type_attr.fset(self, val)
            else:
                warnings.warn(f"Setting a feature value by direct assignment is deprecated. Use <nodemap>.{attribute}.Value = {val}", DeprecationWarning, stacklevel=2)
                _LookupParameter(self.GetInstantCameraNodeMap(), self.GetNodeMap() if self.IsPylonDeviceAttached() else None, attribute).SetValue(val)

    def __dir__(self):
        l = dir(type(self))
        l.extend(self.__dict__.keys())
        try:
            nodes = self.GetInstantCameraNodeMap().GetNodes()
            features = filter(lambda n: n.GetNode().IsFeature(), nodes)
            l.extend(x.GetNode().GetName() for x in features)
        except:
            pass
        try:
            if self.IsPylonDeviceAttached():
                nodes = self.GetNodeMap().GetNodes()
                features = filter(lambda n: n.GetNode().IsFeature(), nodes)
                l.extend(x.GetNode().GetName() for x in features)
        except:
            pass
        return sorted(set(l))

    def __enter__(self):
        if self.IsPylonDeviceAttached():
            self.Open()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.DestroyDevice() #automatically closes the camera and releases the device
        # unregister all configurations to avoid lifetime issues with event handlers that may be registered by the user.
        self.RegisterConfiguration(None, _pylon.RegistrationMode_ReplaceAll, _pylon.Cleanup_None)
        self.RegisterImageEventHandler(None, _pylon.RegistrationMode_ReplaceAll, _pylon.Cleanup_None)
        self.RegisterCameraEventHandler(None, "Dummy", 0, _pylon.RegistrationMode_ReplaceAll, _pylon.Cleanup_None)
        return False
%}
}

%pythonprepend Pylon::CInstantCamera::CInstantCamera %{
    # InstantCamera(firstFound: bool)
    if len(args) == 1 and isinstance(args[0], bool):
        _pylon.InstantCamera_swiginit(self, _pylon.new_InstantCamera())
        tlf = TlFactory.GetInstance()
        if args[0] == FirstFound:
            self.Attach(tlf.CreateFirstDevice())
        else:
            self.Attach(tlf.CreateDevice(DeviceInfo()))
        return
    # InstantCamera(di: DeviceInfo | dict, firstFound: bool)
    if len(args) == 2 and isinstance(args[1], bool):
        di_arg = args[0]
        first_found = args[1]
        if isinstance(di_arg, dict):
            di_arg = InstantCamera._device_info_from_dict(di_arg)
        _pylon.InstantCamera_swiginit(self, _pylon.new_InstantCamera())
        tlf = TlFactory.GetInstance()
        if first_found == FirstFound:
            self.Attach(tlf.CreateFirstDevice(di_arg))
        else:
            self.Attach(tlf.CreateDevice(di_arg))
        return
%}

%pythonprepend Pylon::CInstantCamera::Attach %{
    # Attach(firstFound: bool)
    if len(args) == 1 and isinstance(args[0], bool):
        tlf = TlFactory.GetInstance()
        if args[0] == FirstFound:
            _pylon.InstantCamera_Attach(self, tlf.CreateFirstDevice())
        else:
            _pylon.InstantCamera_Attach(self, tlf.CreateDevice(DeviceInfo()))
        return
    # Attach(di: DeviceInfo | dict, firstFound: bool)
    if len(args) == 2 and isinstance(args[1], bool):
        di_arg = args[0]
        first_found = args[1]
        if isinstance(di_arg, dict):
            di_arg = InstantCamera._device_info_from_dict(di_arg)
        tlf = TlFactory.GetInstance()
        if first_found == FirstFound:
            _pylon.InstantCamera_Attach(self, tlf.CreateFirstDevice(di_arg))
        else:
            _pylon.InstantCamera_Attach(self, tlf.CreateDevice(di_arg))
        return
%}

%include <pylon/ECleanup.h>;
%include <pylon/ERegistrationMode.h>;
%include <pylon/ETimeoutHandling.h>;

// Per-method typemaps for nodemap getters – each wraps the returned
// GenApi::INodeMap& in an NodeMapWrapper carrying the correct ENodeMapType.
// These must appear before %include <pylon/InstantCamera.h> so SWIG uses them
// instead of the generic INodeMap& typemap defined in pylon.i.

%typemap(out) GENAPI_NAMESPACE::INodeMap& Pylon::CInstantCamera::GetNodeMap
%{
    $result = SWIG_NewPointerObj(
        new Pylon::NodeMapWrapper($1, Pylon::NodeMapType_Camera),
        $descriptor(Pylon::NodeMapWrapper*),
        SWIG_POINTER_OWN
    );
%}

%typemap(out) GENAPI_NAMESPACE::INodeMap& Pylon::CInstantCamera::GetTLNodeMap
%{
    $result = SWIG_NewPointerObj(
        new Pylon::NodeMapWrapper($1, Pylon::NodeMapType_DeviceTransportLayer),
        $descriptor(Pylon::NodeMapWrapper*),
        SWIG_POINTER_OWN
    );
%}

%typemap(out) GENAPI_NAMESPACE::INodeMap& Pylon::CInstantCamera::GetStreamGrabberNodeMap
%{
    $result = SWIG_NewPointerObj(
        new Pylon::NodeMapWrapper($1, Pylon::NodeMapType_StreamGrabber),
        $descriptor(Pylon::NodeMapWrapper*),
        SWIG_POINTER_OWN
    );
%}

%typemap(out) GENAPI_NAMESPACE::INodeMap& Pylon::CInstantCamera::GetEventGrabberNodeMap
%{
    $result = SWIG_NewPointerObj(
        new Pylon::NodeMapWrapper($1, Pylon::NodeMapType_EventGrabber),
        $descriptor(Pylon::NodeMapWrapper*),
        SWIG_POINTER_OWN
    );
%}

%typemap(out) GENAPI_NAMESPACE::INodeMap& Pylon::CInstantCamera::GetInstantCameraNodeMap
%{
    $result = SWIG_NewPointerObj(
        new Pylon::NodeMapWrapper($1, Pylon::NodeMapType_InstantCamera),
        $descriptor(Pylon::NodeMapWrapper*),
        SWIG_POINTER_OWN
    );
%}

%include <pylon/InstantCamera.h>;

%extend Pylon::CInstantCamera {
%pythoncode %{
    def _event_handler_refs(self):
        try:
            return object.__getattribute__(self, "_pylon_event_handler_refs")
        except AttributeError:
            refs = {
                "configuration": {},
                "image": {},
                "camera": {},
            }
            object.__setattr__(self, "_pylon_event_handler_refs", refs)
            return refs

    def _clear_event_handler_refs(self):
        self._event_handler_refs()["configuration"].clear()
        self._event_handler_refs()["image"].clear()
        self._event_handler_refs()["camera"].clear()

    def RegisterConfiguration(self, pConfigurator, mode, cleanupProcedure):
        result = _pylon.InstantCamera_RegisterConfiguration(
            self, pConfigurator, mode, cleanupProcedure
        )
        refs = self._event_handler_refs()["configuration"]
        if mode == RegistrationMode_ReplaceAll or pConfigurator is None:
            refs.clear()
        if pConfigurator is not None:
            if cleanupProcedure == Cleanup_Delete:
                pConfigurator.__disown__()
            elif cleanupProcedure == Cleanup_None:
                refs[id(pConfigurator)] = pConfigurator
        return result

    def DeregisterConfiguration(self, pConfigurator):
        result = _pylon.InstantCamera_DeregisterConfiguration(self, pConfigurator)
        self._event_handler_refs()["configuration"].pop(id(pConfigurator), None)
        return result

    def RegisterImageEventHandler(self, pImageEventHandler, mode, cleanupProcedure):
        result = _pylon.InstantCamera_RegisterImageEventHandler(
            self, pImageEventHandler, mode, cleanupProcedure
        )
        refs = self._event_handler_refs()["image"]
        if mode == RegistrationMode_ReplaceAll or pImageEventHandler is None:
            refs.clear()
        if pImageEventHandler is not None:
            if cleanupProcedure == Cleanup_Delete:
                pImageEventHandler.__disown__()
            elif cleanupProcedure == Cleanup_None:
                refs[id(pImageEventHandler)] = pImageEventHandler
        return result

    def DeregisterImageEventHandler(self, pImageEventHandler):
        result = _pylon.InstantCamera_DeregisterImageEventHandler(
            self, pImageEventHandler
        )
        if result:
            self._event_handler_refs()["image"].pop(id(pImageEventHandler), None)
        return result

    def RegisterCameraEventHandler(self, pCameraEventHandler, nodeName, userProvidedId, mode, cleanupProcedure, *args):
        result = _pylon.InstantCamera_RegisterCameraEventHandler(
            self, pCameraEventHandler, nodeName, userProvidedId, mode, cleanupProcedure, *args
        )
        refs = self._event_handler_refs()["camera"]
        if mode == RegistrationMode_ReplaceAll or pCameraEventHandler is None:
            refs.clear()
        if pCameraEventHandler is not None:
            if cleanupProcedure == Cleanup_Delete:
                pCameraEventHandler.__disown__()
            elif cleanupProcedure == Cleanup_None:
                refs[(id(pCameraEventHandler), nodeName)] = pCameraEventHandler
        return result

    def DeregisterCameraEventHandler(self, pCameraEventHandler, nodeName):
        result = _pylon.InstantCamera_DeregisterCameraEventHandler(
            self, pCameraEventHandler, nodeName
        )
        if result:
            self._event_handler_refs()["camera"].pop(
                (id(pCameraEventHandler), nodeName), None
            )
        return result

    def DestroyDevice(self):
        result = _pylon.InstantCamera_DestroyDevice(self)
        self._clear_event_handler_refs()
        return result
%}
}
