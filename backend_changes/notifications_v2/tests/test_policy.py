import importlib.util
import json
from pathlib import Path
import unittest
from datetime import datetime, timedelta, timezone

spec = importlib.util.spec_from_file_location('notification_delivery', Path(__file__).resolve().parents[1] / 'notification_delivery.py')
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)


class DevicePolicyTests(unittest.TestCase):
    def prepare(self, options=None, data=None):
        return delivery.prepare_device_push(7, json.dumps(options or {}), 'Test', 'private text',
            data or {'type': 'new_message', 'chat_id': '42', 'message_id': '9'})

    def test_legacy_device_keeps_delivery_and_gets_account_and_stable_event(self):
        title, body, data = self.prepare()
        self.assertEqual(data['account_id'], '7')
        self.assertEqual(data['event_id'], 'message:42:9')
        self.assertEqual(data['notification_protocol'], '1')
        self.assertEqual(body, 'private text')

    def test_opt_out_categories_and_device_mute(self):
        for options in ({'enabled': False}, {'messages': False}, {'muted_chat_ids': [42]}):
            self.assertIsNone(self.prepare(options))
        self.assertIsNotNone(self.prepare({'muted_chat_ids': [43]}))

    def test_preview_and_secret_content_are_generic(self):
        self.assertEqual(self.prepare({'preview': False})[1], 'New message')
        self.assertEqual(self.prepare({'locale': 'ru'}, {'type': 'new_message', 'is_secret': 'true'})[1], 'Зашифрованное сообщение')

    def test_call_expiry_and_cancellation_bypass_switch(self):
        now = datetime.now(timezone.utc)
        self.assertIsNone(self.prepare(data={'type': 'incoming_call', 'expires_at': (now - timedelta(seconds=1)).isoformat()}))
        self.assertIsNotNone(self.prepare({'enabled': False, 'calls': False}, {'type': 'call_ended', 'room_id': 'room'}))

    def test_preferences_are_validated_and_do_not_use_moderation_mute(self):
        value = json.loads(delivery.preferences({'notification_protocol': 2,
            'notification_preferences': {'muted_chat_ids': ['42', 42, -1], 'locale': 'ru-RU'}}))
        self.assertEqual(value['muted_chat_ids'], [42])
        self.assertEqual(value['protocol'], 2)
        self.assertNotIn('is_muted', value)
        with self.assertRaises(ValueError):
            delivery.preferences({'notification_preferences': {'muted_chat_ids': '42'}})

    def test_queue_does_not_dispatch_before_commit(self):
        class Transaction:
            info = {}
        db = Transaction()
        delivery.queue_push(db, ['fixture-token'], 'Title', 'Body', {'message_id': '9'})
        self.assertEqual(len(db.info['notification_pushes']), 1)
        db.info.clear()  # Router rollback discards it.
        self.assertEqual(db.info, {})


if __name__ == '__main__':
    unittest.main()
