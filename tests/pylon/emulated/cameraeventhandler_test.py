"""\
This unit test checks the CameraEventHandler class
introduced by `src/pylon/CameraEventHandler.i`.
"""
from pylonemutestcase import PylonEmuTestCase
from pypylon import pylon
import gc
import unittest
import weakref


class TestCameraEventHandler(pylon.CameraEventHandler):
    def __init__(self):
        super().__init__()
        # OnCameraEvent tracking
        self.camera_passed = None
        self.user_provided_id_passed = None
        self.node_passed = None
        self.call_count = 0
        # OnCameraEventHandlerRegistered tracking
        self.registered_camera = None
        self.registered_node_name = None
        self.registered_user_id = None
        # OnCameraEventHandlerDeregistered tracking
        self.deregistered_camera = None
        self.deregistered_node_name = None
        self.deregistered_user_id = None

    # Only very short processing tasks should be performed by this method. Otherwise, the event notification will block the
    # processing of images.
    def OnCameraEvent(self, camera, userProvidedId, node):
        self.node_passed = node
        self.user_provided_id_passed = userProvidedId
        self.camera_passed = camera
        self.call_count += 1

    def OnCameraEventHandlerRegistered(self, camera, nodeName, userProvidedId):
        self.registered_camera = camera
        self.registered_node_name = nodeName
        self.registered_user_id = userProvidedId

    def OnCameraEventHandlerDeregistered(self, camera, nodeName, userProvidedId):
        self.deregistered_camera = camera
        self.deregistered_node_name = nodeName
        self.deregistered_user_id = userProvidedId


class CameraEventHandlerTestSuite(PylonEmuTestCase):

    # ------------------------------------------------------------------
    # Construction
    # ------------------------------------------------------------------

    def test_construction(self):
        """Default construction produces a valid handler object."""
        handler = pylon.CameraEventHandler()
        self.assertIsNotNone(handler)

    # ------------------------------------------------------------------
    # OnCameraEvent
    # ------------------------------------------------------------------

    def test_on_camera_event(self):
        """OnCameraEvent is called with the correct camera, user id, and parameter-typed node."""
        handler = TestCameraEventHandler()
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.CameraContext = 4711
            # 5 parameters
            camera.RegisterCameraEventHandler(handler, "Width", 12345, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            # 6 parameters
            camera.RegisterCameraEventHandler(handler, "Gain", 1234, pylon.RegistrationMode_Append, pylon.Cleanup_None, pylon.CameraEventAvailability_Mandatory)
            # Note: The camera event handler is intended for nodes implementing the asynchronous event mechanism.
            # It is merely based on genicam node callbacks that's why it can be used for any parameter/node.
            # When using the event handler in conjunction with the instant camera the instant camera will take
            # care of registering the node callback handlers if you change the camera device attached to the instant camera.
            try:
                camera.Gain.SetToMaximum()
                self.assertEqual(handler.call_count, 1)
                self.assertEqual(handler.camera_passed.CameraContext, 4711)
                self.assertEqual(handler.user_provided_id_passed, 1234)
                self.assertTrue(handler.node_passed.Equals(camera.Gain))
                camera.Width.SetToMaximum()
                self.assertEqual(handler.call_count, 2)
                self.assertEqual(handler.camera_passed.CameraContext, 4711)
                self.assertEqual(handler.user_provided_id_passed, 12345)
                self.assertTrue(handler.node_passed.Equals(camera.Width))
            finally:
                # Explicitly deregister before DestroyDevice() to prevent a use-after-free:
                # handler.camera_passed = camera creates a cycle that the GC may collect
                # before the implicit deregistration inside DestroyDevice() fires.
                camera.DeregisterCameraEventHandler(handler, "Width")
                camera.DeregisterCameraEventHandler(handler, "Gain")

    # ------------------------------------------------------------------
    # OnCameraEventHandlerRegistered
    # ------------------------------------------------------------------

    def test_on_camera_event_handler_registered(self):
        """OnCameraEventHandlerRegistered is called with the correct camera, node name, and user id."""
        handler = TestCameraEventHandler()
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.CameraContext = 4711
            camera.RegisterCameraEventHandler(handler, "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            try:
                self.assertIsNotNone(handler.registered_camera)
                self.assertEqual(handler.registered_camera.CameraContext, 4711)
                self.assertEqual(handler.registered_node_name, "Gain")
                self.assertEqual(handler.registered_user_id, 1234)
            finally:
                camera.DeregisterCameraEventHandler(handler, "Gain")

    def test_cleanup_none_handler_is_kept_alive_by_camera(self):
        """Cleanup_None camera event handlers stay alive while registered."""
        handler = TestCameraEventHandler()
        handler_ref = weakref.ref(handler)
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.RegisterCameraEventHandler(
                handler, "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None
            )
            del handler
            gc.collect()
            self.assertIsNotNone(handler_ref())
            camera.DeregisterCameraEventHandler(handler_ref(), "Gain")
        gc.collect()
        self.assertIsNone(handler_ref())

    # ------------------------------------------------------------------
    # OnCameraEventHandlerDeregistered
    # ------------------------------------------------------------------

    def test_on_camera_event_handler_deregistered(self):
        """OnCameraEventHandlerDeregistered is called with the correct camera, node name, and user id."""
        handler = TestCameraEventHandler()
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.CameraContext = 4711
            camera.RegisterCameraEventHandler(handler, "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)
            camera.DeregisterCameraEventHandler(handler, "Gain")
            self.assertIsNotNone(handler.deregistered_camera)
            self.assertEqual(handler.deregistered_camera.CameraContext, 4711)
            self.assertEqual(handler.deregistered_node_name, "Gain")
            self.assertEqual(handler.deregistered_user_id, 1234)

    # ------------------------------------------------------------------
    # DestroyCameraEventHandler
    # ------------------------------------------------------------------

    def test_destroy_camera_event_handler_called_for_cleanup_delete(self):
        """DestroyCameraEventHandler is called when the handler is deregistered with Cleanup_Delete."""
        call_log = []

        class DestructionTrackingHandler(pylon.CameraEventHandler):
            def __init__(self):
                super().__init__()

            def DestroyCameraEventHandler(self):
                call_log.append(True)

        handler = DestructionTrackingHandler()
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.RegisterCameraEventHandler(handler, "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)
            camera.DeregisterCameraEventHandler(handler, "Gain")
            self.assertEqual(len(call_log), 1)

    # ------------------------------------------------------------------
    # RegisterCameraEventHandler with None (deregister all)
    # ------------------------------------------------------------------

    def test_register_camera_event_handler_none_cleanup_none(self):
        """RegisterCameraEventHandler(None, ..., Cleanup_None) deregisters all handlers without error."""
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.RegisterCameraEventHandler(pylon.CameraEventHandler(), "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)
            # Passing None as handler deregisters all currently registered camera event handlers.
            camera.RegisterCameraEventHandler(None, "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_None)

    def test_register_camera_event_handler_none_cleanup_delete(self):
        """RegisterCameraEventHandler(None, ..., Cleanup_Delete) deregisters all handlers without error."""
        with pylon.InstantCamera(self.get_camera_traits(), pylon.FirstFound) as camera:
            camera.RegisterCameraEventHandler(pylon.CameraEventHandler(), "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)
            # Passing None as handler deregisters all currently registered camera event handlers.
            camera.RegisterCameraEventHandler(None, "Gain", 1234, pylon.RegistrationMode_ReplaceAll, pylon.Cleanup_Delete)


if __name__ == "__main__":
    unittest.main()
