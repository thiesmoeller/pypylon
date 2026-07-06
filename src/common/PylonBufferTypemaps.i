////////////////////////////////////////////////////////////////////////////////
//
// Shared buffer output typemap.
//
// ABI note: PyByteArray_FromStringAndSize is available with the Python 3.9
// limited ABI. Do not replace this with PyObject_GetBuffer-based plumbing here;
// Py_buffer is not part of the stable ABI before Python 3.11.
//

%typemap(in,noblock=1,numinputs=0, noblock=1)
( void **buf_mem, size_t *length)
($*1_ltype temp = 0, $*2_ltype tempn) {
  $1 = &temp;
  $2 = &tempn;
}
%typemap(freearg,match="in", noblock=1) (void **buf_mem, size_t *length) "";

%typemap(argout, noblock=1) (void ** buf_mem, size_t *length) {
  if (*$1) {
    PyObject *buffer = PyByteArray_FromStringAndSize(
        (const char *)*$1, %numeric_cast(*$2, int)
        );
    if (!buffer) {
      SWIG_fail;
    }
    %append_output(buffer);
  }
};
