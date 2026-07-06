////////////////////////////////////////////////////////////////////////////////
//
// Shared StringList_t input typemaps.
//
// Accept Python str and bytes while staying compatible with the Python 3.9
// limited ABI. Generic buffer-protocol input is intentionally not used here.
//

%typemap(typecheck,precedence=SWIG_TYPECHECK_STRING_ARRAY)
const Pylon::StringList_t &
{
    $1 = PyList_Check($input) ? 1 : 0;
}

%typemap(in, numinputs=1)
const Pylon::StringList_t & (Pylon::StringList_t str_list)
{
    if (PyList_Check($input)) {
        Py_ssize_t size = PyList_Size($input);
        str_list.resize(size);
        Py_ssize_t i = 0;
        for (i = 0; i < size; i++) {
            PyObject *o = PyList_GetItem($input, i);
            if (PyBytes_Check(o)) {
                str_list[i] = GENICAM_NAMESPACE::gcstring(PyBytes_AsString(o));
            } else if (PyUnicode_Check(o)) {
                PyObject *utf8 = PyUnicode_AsUTF8String(o);
                if (!utf8) {
                    SWIG_fail;
                }
                str_list[i] = GENICAM_NAMESPACE::gcstring(PyBytes_AsString(utf8));
                Py_DECREF(utf8);
            } else {
                PyErr_SetString(PyExc_TypeError, "list must contain strings");
                SWIG_fail;
            }
        }
        $1 = &str_list;
    } else {
        PyErr_SetString(PyExc_TypeError, "not a list");
        SWIG_fail;
    }
}

// Make sure the above typemap is not applied to output const references.
%typemap(argout, noblock=1) const StringList_t & {}
