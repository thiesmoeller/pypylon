%rename(Recipe) Pylon::DataProcessing::CRecipe;
%rename(OutputObserver) Pylon::DataProcessing::IOutputObserver;

%ignore GetParameters;
%ignore GetInputTypeName;
%ignore GetOutputTypeName;
%ignore UnregisterOutputObserver;
%ignore RegisterOutputObserver;
%ignore TriggerUpdate;
%ignore TriggerUpdateAsync;

%ignore GetOutputNames;
%rename(GetOutputNames) GetOutputNames2;
%rename(UnregisterOutputObserver) UnregisterOutputObserver2;
%rename(RegisterOutputObserver) RegisterOutputObserver2;
%rename(TriggerUpdate) TriggerUpdate2;
%rename(TriggerUpdateAsync) TriggerUpdateAsync2;

#define CLock GENAPI_NAMESPACE::CLock

%typemap(typecheck,precedence=SWIG_TYPECHECK_CHAR)  (const void* pBuffer, size_t bufferSize)
   %{
       $1 = (PyBytes_Check($input) || PyByteArray_Check($input)) ? 1 : 0;
   %}

%typemap(in) (const void* pBuffer, size_t bufferSize)
    %{
        if (PyBytes_Check($input)) {
            $1 = PyBytes_AsString($input);
            $2 = PyBytes_Size($input);
        } else if (PyByteArray_Check($input)) {
            $1 = PyByteArray_AsString($input);
            $2 = PyByteArray_Size($input);
        } else {
            PyErr_SetString(
              PyExc_TypeError,
              "Invalid type of buffer (bytes and bytearray are supported)!."
            );
            SWIG_fail;
        }
    %}

%include <pylondataprocessing/Recipe.h>;

%extend Pylon::DataProcessing::CRecipe {

    void GetOutputNames2(StringList_t& result) const
    {
        $self->GetOutputNames(result);
    }

    void GetAllParameterNames(StringList_t& result)
    {
        result = $self->GetParameters().GetAllParameterNames();
    }

    bool ContainsParameter(const Pylon::String_t& fullname)
    {
        bool result = $self->GetParameters().Contains(fullname);
        return result;
    }

    GENAPI_NAMESPACE::INode* GetParameter(const Pylon::String_t& fullname)
    {
        Pylon::CParameter parameter = $self->GetParameters().Get(fullname);
        return parameter.IsValid() ? parameter.GetNode() : nullptr;
    }

    void RegisterOutputObserver2(const StringList_t& outputFullNames, IOutputObserver* pObserver, ERegistrationMode mode, intptr_t userProvidedId = 0)
    {
        $self->RegisterOutputObserver(outputFullNames, pObserver, mode, userProvidedId);
    }
    
    bool UnregisterOutputObserver2(IOutputObserver* pObserver, intptr_t userProvidedId = 0)
    {
        bool result = $self->UnregisterOutputObserver(pObserver, userProvidedId);
        return result;
    }
    
    Pylon::DataProcessing::CUpdate TriggerUpdateAsync2(Pylon::DataProcessing::CVariantContainer inputCollection, Pylon::DataProcessing::IUpdateObserver* pObserver = nullptr, intptr_t userProvidedId = 0)
    {
        Pylon::DataProcessing::CUpdate result = self->TriggerUpdateAsync(inputCollection, pObserver, userProvidedId);
        return result;
    }
    
    Pylon::DataProcessing::CUpdate TriggerUpdate2(Pylon::DataProcessing::CVariantContainer inputCollection, unsigned int timeoutMs, Pylon::ETimeoutHandling timeoutHandling = Pylon::TimeoutHandling_ThrowException, Pylon::DataProcessing::IUpdateObserver* pObserver = nullptr, intptr_t userProvidedId = 0)
    {
        Pylon::DataProcessing::CUpdate result = self->TriggerUpdate(inputCollection, timeoutMs, timeoutHandling, pObserver, userProvidedId);
        return result;
    }

%pythoncode %{
    def _observer_refs(self):
        try:
            return object.__getattribute__(self, "_pylondp_observer_refs")
        except AttributeError:
            refs = {
                "output": {},
                "event": {},
                "update": {},
            }
            object.__setattr__(self, "_pylondp_observer_refs", refs)
            return refs

    def _clear_observer_refs(self):
        refs = self._observer_refs()
        refs["output"].clear()
        refs["event"].clear()
        refs["update"].clear()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.Unload()
        # Output observers and update observers are automatically unregistered when the recipe is unloaded,
        # so we don't need to explicitly unregister them here.
        self.UnregisterEventObserver()
        self._clear_observer_refs()
        return False

    def Load(self, *args):
        return _pylondataprocessing.Recipe_Load(self, *args)

    def Unload(self):
        result = _pylondataprocessing.Recipe_Unload(self)
        self._clear_observer_refs()
        return result

    def RegisterEventObserver(self, pObserver):
        result = _pylondataprocessing.Recipe_RegisterEventObserver(self, pObserver)
        refs = self._observer_refs()["event"]
        refs.clear()
        if pObserver is not None:
            refs[id(pObserver)] = pObserver
        return result

    def UnregisterEventObserver(self):
        result = _pylondataprocessing.Recipe_UnregisterEventObserver(self)
        self._observer_refs()["event"].clear()
        return result

    def RegisterAllOutputsObserver(self, pObserver, mode, userProvidedId=0):
        result = _pylondataprocessing.Recipe_RegisterAllOutputsObserver(
            self, pObserver, mode, userProvidedId
        )
        refs = self._observer_refs()["output"]
        if mode == pypylon.pylon.RegistrationMode_ReplaceAll or pObserver is None:
            refs.clear()
        if pObserver is not None:
            refs[(id(pObserver), userProvidedId)] = pObserver
        return result

    def RegisterOutputObserver(self, outputFullNames, pObserver, mode, userProvidedId=0):
        result = _pylondataprocessing.Recipe_RegisterOutputObserver(
            self, outputFullNames, pObserver, mode, userProvidedId
        )
        refs = self._observer_refs()["output"]
        if mode == pypylon.pylon.RegistrationMode_ReplaceAll or pObserver is None:
            refs.clear()
        if pObserver is not None:
            refs[(id(pObserver), userProvidedId)] = pObserver
        return result

    def UnregisterOutputObserver(self, pObserver, userProvidedId=0):
        result = _pylondataprocessing.Recipe_UnregisterOutputObserver(
            self, pObserver, userProvidedId
        )
        if result:
            self._observer_refs()["output"].pop((id(pObserver), userProvidedId), None)
        return result

    def TriggerUpdateAsync(self, inputCollection, pObserver=None, userProvidedId=0):
        result = _pylondataprocessing.Recipe_TriggerUpdateAsync(
            self, inputCollection, pObserver, userProvidedId
        )
        if pObserver is not None:
            self._observer_refs()["update"][(id(pObserver), userProvidedId)] = pObserver
        return result

    def TriggerUpdate(self, inputCollection, timeoutMs, timeoutHandling=pypylon.pylon.TimeoutHandling_ThrowException, pObserver=None, userProvidedId=0):
        result = _pylondataprocessing.Recipe_TriggerUpdate(
            self, inputCollection, timeoutMs, timeoutHandling, pObserver, userProvidedId
        )
        if pObserver is not None:
            self._observer_refs()["update"][(id(pObserver), userProvidedId)] = pObserver
        return result
%}
}
