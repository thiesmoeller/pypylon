// ImageMixin.i
//
// Module-level Python helper functions shared by PylonDataComponent,
// PylonImage and GrabResultPtr to avoid code duplication.

%nothread _pylon_GetImageFormatDescriptor;

%inline %{
PyObject* _pylon_GetImageFormatDescriptor(Pylon::EPixelType pixelType, size_t width, size_t height)
{
    size_t channels = 0;
    int dtypeCode = -1;
    const char* format = 0;

    if (Pylon::IsPacked(pixelType))
    {
        PyErr_SetString(PyExc_ValueError, "Packed Formats are not supported with numpy interface");
        return NULL;
    }

    switch (pixelType)
    {
        case Pylon::PixelType_Mono8:
        case Pylon::PixelType_BayerGR8:
        case Pylon::PixelType_BayerRG8:
        case Pylon::PixelType_BayerGB8:
        case Pylon::PixelType_BayerBG8:
        case Pylon::PixelType_Confidence8:
        case Pylon::PixelType_Coord3D_C8:
            dtypeCode = 0;
            format = "B";
            break;

        case Pylon::PixelType_Mono10:
        case Pylon::PixelType_BayerGR10:
        case Pylon::PixelType_BayerRG10:
        case Pylon::PixelType_BayerGB10:
        case Pylon::PixelType_BayerBG10:
        case Pylon::PixelType_Mono12:
        case Pylon::PixelType_BayerGR12:
        case Pylon::PixelType_BayerRG12:
        case Pylon::PixelType_BayerGB12:
        case Pylon::PixelType_BayerBG12:
        case Pylon::PixelType_Mono16:
        case Pylon::PixelType_BayerGR16:
        case Pylon::PixelType_BayerRG16:
        case Pylon::PixelType_BayerGB16:
        case Pylon::PixelType_BayerBG16:
        case Pylon::PixelType_Confidence16:
        case Pylon::PixelType_Coord3D_C16:
            dtypeCode = 1;
            format = "H";
            break;

        case Pylon::PixelType_RGB8packed:
        case Pylon::PixelType_BGR8packed:
            dtypeCode = 0;
            format = "B";
            channels = 3;
            break;

        case Pylon::PixelType_RGB12packed:
        case Pylon::PixelType_BGR12packed:
        case Pylon::PixelType_RGB10packed:
        case Pylon::PixelType_BGR10packed:
            dtypeCode = 1;
            format = "H";
            channels = 3;
            break;

        case Pylon::PixelType_YUV422_YUYV_Packed:
        case Pylon::PixelType_YUV422packed:
            dtypeCode = 0;
            format = "B";
            channels = 2;
            break;

        case Pylon::PixelType_Coord3D_ABC32f:
            dtypeCode = 2;
            format = "f";
            channels = 3;
            break;

        case Pylon::PixelType_Data32f:
            dtypeCode = 2;
            format = "f";
            channels = 1;
            break;

        case Pylon::PixelType_BiColorRGBG8:
        case Pylon::PixelType_BiColorBGRG8:
            dtypeCode = 0;
            format = "B";
            width *= 2;
            break;

        case Pylon::PixelType_BiColorRGBG10:
        case Pylon::PixelType_BiColorBGRG10:
        case Pylon::PixelType_BiColorRGBG12:
        case Pylon::PixelType_BiColorBGRG12:
            dtypeCode = 1;
            format = "H";
            width *= 2;
            break;

        default:
            PyErr_SetString(PyExc_ValueError, "Pixel format currently not supported");
            return NULL;
    }

    PyObject* shape = PyTuple_New(channels ? 3 : 2);
    if (!shape)
    {
        return NULL;
    }

    PyObject* pyHeight = PyLong_FromSize_t(height);
    PyObject* pyWidth = PyLong_FromSize_t(width);
    if (!pyHeight || !pyWidth)
    {
        Py_XDECREF(pyHeight);
        Py_XDECREF(pyWidth);
        Py_DECREF(shape);
        return NULL;
    }
    PyTuple_SetItem(shape, 0, pyHeight);
    PyTuple_SetItem(shape, 1, pyWidth);

    if (channels)
    {
        PyObject* pyChannels = PyLong_FromSize_t(channels);
        if (!pyChannels)
        {
            Py_DECREF(shape);
            return NULL;
        }
        PyTuple_SetItem(shape, 2, pyChannels);
    }

    PyObject* pyDtypeCode = PyLong_FromLong(dtypeCode);
    PyObject* pyFormat = PyUnicode_FromString(format);
    if (!pyDtypeCode || !pyFormat)
    {
        Py_XDECREF(pyDtypeCode);
        Py_XDECREF(pyFormat);
        Py_DECREF(shape);
        return NULL;
    }

    PyObject* result = PyTuple_New(3);
    if (!result)
    {
        Py_DECREF(shape);
        Py_DECREF(pyDtypeCode);
        Py_DECREF(pyFormat);
        return NULL;
    }

    PyTuple_SetItem(result, 0, shape);
    PyTuple_SetItem(result, 1, pyDtypeCode);
    PyTuple_SetItem(result, 2, pyFormat);
    return result;
}
%}

%pythoncode %{
from contextlib import contextmanager
import sys

def _image_dtype_from_code(code):
    return (_pylon_numpy.uint8, _pylon_numpy.uint16, _pylon_numpy.float32)[code]

def _image_get_image_format(self, pt=None):
    """Common GetImageFormat implementation used by PylonDataComponent, PylonImage and GrabResultPtr."""
    if pt is None:
        pt = self.GetPixelType()
    shape, dtype_code, format = _pylon_GetImageFormatDescriptor(pt, self.GetWidth(), self.GetHeight())
    return (shape, _image_dtype_from_code(dtype_code), format)


def _image_get_array(self, raw, get_buffer_func, get_size_func, strides_func=None):
    """Common GetArray core implementation.

    Parameters
    ----------
    raw            : bool          – return raw byte buffer when True
    get_buffer_func: callable()    – returns the image/payload buffer
    get_size_func  : callable()    – returns the size for the raw case
    strides_func   : callable(dtype) or None
                                  – optional function that receives the numpy
                                    dtype and returns strides (or None for
                                    contiguous arrays).
    """
    if raw:
        shape = get_size_func()
        buf = get_buffer_func()
        return _pylon_numpy.ndarray(shape, dtype=_pylon_numpy.uint8, buffer=buf)

    pt = self.GetPixelType()
    if IsPacked(pt):
        unpacked = ImageFormatConverter._Unpack(self)
        shape, dtype, format = _image_get_image_format(unpacked)
        buf = unpacked.GetBuffer()
    else:
        shape, dtype, format = self.GetImageFormat(pt)
        buf = get_buffer_func()

    strides = strides_func(dtype) if strides_func is not None else None
    return _pylon_numpy.ndarray(shape, dtype=dtype, buffer=buf, strides=strides)


def _image_array_zero_copy_gen(self, memory_view_func, raw=False):
    """Generator backing GetArrayZeroCopy for all image-like classes.

    Callers should wrap this with @contextmanager + @needs_numpy and
    yield from it::

        @contextmanager
        @needs_numpy
        def GetArrayZeroCopy(self, raw=False):
            yield from _image_array_zero_copy_gen(self, self.GetMemoryView, raw)
    """
    # For packed formats we cannot zero-copy; unpack into a CPylonImage first
    # and hand back a regular array.
    pt = self.GetPixelType()
    if IsPacked(pt):
        yield ImageFormatConverter._Unpack(self).GetArray()
        return

    mv = memory_view_func()
    if not raw:
        shape, dtype, format = self.GetImageFormat()
        mv = mv.cast(format, shape)

    ar = _pylon_numpy.asarray(mv)

    # trace external references to array
    initial_refcount = sys.getrefcount(ar)

    # yield the array to the context code
    yield ar

    # detect if more refs than the one from the yield are held
    if sys.getrefcount(ar) > initial_refcount + 1:
        raise RuntimeError("Please remove any references to the array before leaving context manager scope!!!")

    # release the memory view
    mv.release()
%}
