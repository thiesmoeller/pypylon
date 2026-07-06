////////////////////////////////////////////////////////////////////////////////
//
// Shared Python C API compatibility policy.
//
// pypylon supports Python 3.9+ and can be built with the stable ABI. The
// Py_buffer / PyObject_GetBuffer APIs are only part of the stable ABI starting
// with Python 3.11, so code using the generic buffer protocol must be gated.
//

%begin %{

#ifdef Py_LIMITED_API
#include <stdlib.h> // malloc / free
#endif

#if !defined(Py_LIMITED_API) || Py_LIMITED_API+0 >= 0x030b0000
#define PYPYLON_HAS_PYBUFFER_PROTOCOL 1
#else
#define PYPYLON_HAS_PYBUFFER_PROTOCOL 0
#endif

#ifdef Py_LIMITED_API
// Although PyMemoryView_FromMemory has been part of the limited API since
// version 3.3, the flags PyBUF_READ and PyBUF_WRITE are not defined in newer
// Python headers unless Py_LIMITED_API is set to >= 3.11.
#ifndef PyBUF_READ
#define PyBUF_READ  0x100
#endif
#ifndef PyBUF_WRITE
#define PyBUF_WRITE 0x200
#endif
#endif

%}
