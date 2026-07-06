"""\
This unit test checks all of the mapped pypylon API introduced by ImageEventHandler.i.
"""
from pylonemutestcase import PylonEmuTestCase
from pypylon import pylon
import gc
import threading
import unittest
import weakref


class TestImageEventHandler(pylon.ImageEventHandler):
    def __init__(self):
        super().__init__()
        self.registered_camera = None
        self.deregistered_camera = None
        self.grabbed_camera = None
        self.grab_result = None
        self.image_grabbed_event = threading.Event()
        self.images_skipped_camera = None
        self.count_of_skipped_images = 0

    def OnImageEventHandlerRegistered(self, camera):
        self.registered_camera = camera

    def OnImageEventHandlerDeregistered(self, camera):
        self.deregistered_camera = camera

    def OnImageGrabbed(self, camera, grab_result):
        if not self.image_grabbed_event.is_set():
            self.grabbed_camera = camera
            # you need shallow copy the result to keep it, grab_result will be released after the event handler returns
            self.grab_result = pylon.GrabResult(grab_result)
            self.image_grabbed_event.set()

    def OnImagesSkipped(self, camera, count_of_skipped_images):
        self.images_skipped_camera = camera
        self.count_of_skipped_images = count_of_skipped_images


class ImageEventHandlerTestSuite(PylonEmuTestCase):

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------

    def test_construction(self):
        """Default construction produces a valid handler object."""
        handler = pylon.ImageEventHandler()
        self.assertIsNotNone(handler)

    # ------------------------------------------------------------------
    # OnImageGrabbed
    # ------------------------------------------------------------------

    def test_on_image_grabbed(self):
        """OnImageGrabbed is called with the correct camera and a valid grab result."""
        handler = TestImageEventHandler()
        with pylon.InstantCamera() as camera:
            camera.CameraContext = 4711
            camera.RegisterImageEventHandler(handler, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            try:
                camera.Attach(self.get_camera_traits(), pylon.FirstFound)
                camera.Open()
                camera.ExposureTime.SetToMinimum()
                camera.StartGrabbing(pylon.GrabStrategy_OneByOne, pylon.GrabLoop_ProvidedByInstantCamera)
                self.assertTrue(handler.image_grabbed_event.wait(timeout=5.0))
                self.assertEqual(handler.grabbed_camera.CameraContext, 4711)
                self.assertTrue(handler.grab_result.GrabSucceeded())
                camera.StopGrabbing()
            finally:
                camera.DeregisterImageEventHandler(handler)

    # ------------------------------------------------------------------
    # OnImagesSkipped
    # ------------------------------------------------------------------

    def test_on_images_skipped(self):
        """OnImagesSkipped is called with the correct camera and a positive skip count."""
        handler = TestImageEventHandler()
        with pylon.InstantCamera() as camera:
            camera.CameraContext = 4711
            camera.RegisterImageEventHandler(handler, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            try:
                camera.Attach(self.get_camera_traits(), pylon.FirstFound)
                camera.Open()
                camera.ExposureTime.SetToMinimum()
                camera.OutputQueueSize.Value = 1
                camera.StartGrabbing(pylon.GrabStrategy_LatestImages, pylon.GrabLoop_ProvidedByUser)
                # RetrieveResult is not called but the camera is grabbing and providing images
                # Now we neet wait for it to overflow the output queue
                for n in range(100):
                    camera.GetGrabStopWaitObject().Wait(10)
                    # use 5 here to make sure the grab result is picked up by the internal grab engine thread
                    if camera.StreamGrabberNodeMap.Statistic_Total_Buffer_Count.Value > 5:
                        break
                with camera.RetrieveResult(200, pylon.TimeoutHandling_Return) as result:
                    pass
                self.assertEqual(handler.images_skipped_camera.CameraContext, 4711)
                self.assertGreater(handler.count_of_skipped_images, 0)
                camera.StopGrabbing()
            finally:
                camera.DeregisterImageEventHandler(handler)

    # ------------------------------------------------------------------
    # OnImageEventHandlerRegistered
    # ------------------------------------------------------------------

    def test_on_image_event_handler_registered(self):
        """OnImageEventHandlerRegistered is called with the correct camera when the handler is registered."""
        handler = TestImageEventHandler()
        with pylon.InstantCamera() as camera:
            camera.CameraContext = 4711
            camera.RegisterImageEventHandler(handler, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            try:
                self.assertIsNotNone(handler.registered_camera)
                self.assertEqual(handler.registered_camera.CameraContext, 4711)
            finally:
                camera.DeregisterImageEventHandler(handler)

    def test_cleanup_none_handler_is_kept_alive_by_camera(self):
        """Cleanup_None image event handlers stay alive while registered."""
        handler = TestImageEventHandler()
        handler_ref = weakref.ref(handler)
        with pylon.InstantCamera() as camera:
            camera.RegisterImageEventHandler(handler, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            del handler
            gc.collect()
            self.assertIsNotNone(handler_ref())
            camera.DeregisterImageEventHandler(handler_ref())
        gc.collect()
        self.assertIsNone(handler_ref())

    # ------------------------------------------------------------------
    # OnImageEventHandlerDeregistered
    # ------------------------------------------------------------------

    def test_on_image_event_handler_deregistered(self):
        """OnImageEventHandlerDeregistered is called with the correct camera when the handler is deregistered."""
        handler = TestImageEventHandler()
        with pylon.InstantCamera() as camera:
            camera.CameraContext = 4711
            camera.RegisterImageEventHandler(handler, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            camera.DeregisterImageEventHandler(handler)
            self.assertIsNotNone(handler.deregistered_camera)
            self.assertEqual(handler.deregistered_camera.CameraContext, 4711)

    # ------------------------------------------------------------------
    # DestroyImageEventHandler
    # ------------------------------------------------------------------

    def test_destroy_image_event_handler_called_for_cleanup_delete(self):
        """DestroyImageEventHandler is called when the handler is deregistered with Cleanup_Delete."""
        call_log = []

        class DestructionTrackingHandler(pylon.ImageEventHandler):
            def __init__(self):
                super().__init__()

            def DestroyImageEventHandler(self):
                call_log.append(True)

        handler = DestructionTrackingHandler()
        with pylon.InstantCamera() as camera:
            camera.RegisterImageEventHandler(handler, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)
            camera.DeregisterImageEventHandler(handler)
            self.assertEqual(len(call_log), 1)

    # ------------------------------------------------------------------
    # RegisterImageEventHandler with None (deregister all)
    # ------------------------------------------------------------------

    def test_register_image_event_handler_none_cleanup_none(self):
        """RegisterImageEventHandler(None, ..., Cleanup_None) deregisters all handlers without error."""
        with pylon.InstantCamera() as camera:
            camera.RegisterImageEventHandler(pylon.ImageEventHandler(), pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)
            # Passing None as handler deregisters all currently registered image event handlers.
            camera.RegisterImageEventHandler(None, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)

    def test_register_image_event_handler_none_cleanup_delete(self):
        """RegisterImageEventHandler(None, ..., Cleanup_Delete) deregisters all handlers without error."""
        with pylon.InstantCamera() as camera:
            camera.RegisterImageEventHandler(pylon.ImageEventHandler(), pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)
            # Passing None as handler deregisters all currently registered image event handlers.
            camera.RegisterImageEventHandler(None, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)


if __name__ == "__main__":
    unittest.main()
