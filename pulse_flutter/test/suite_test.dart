import 'widgets/chat_productivity_test.dart' as chat_productivity;
import 'services/encrypted_draft_sync_test.dart' as encrypted_draft_sync;
import 'unit/encrypted_draft_codec_test.dart' as encrypted_draft_codec;
import 'services/live_location_service_test.dart' as live_location;
import 'widgets/chat_extras_test.dart' as chat_extras;
import 'widgets/file_request_menu_test.dart' as file_request;
import 'widgets/media_local_path_security_test.dart' as media_local_path_security;
import 'widgets/custom_emoji_forms_test.dart' as audit_emoji_forms;
import 'features/security/app_lock_lifecycle_test.dart' as audit_app_lock;
import 'providers/auth_lifecycle_race_test.dart' as audit_auth;
import 'core/account_draft_storage_test.dart' as audit_drafts;
import 'providers/chat_account_boundary_test.dart' as audit_accounts;
import 'providers/send_account_fence_test.dart' as audit_send_fence;
import 'providers/custom_emoji_lifecycle_test.dart' as audit_emoji_lifecycle;
import 'providers/niosgram_race_test.dart' as audit_feed_races;
import 'widgets/create_post_media_submission_test.dart' as audit_post_media;
import 'widgets/shared_feed_post_actions_test.dart' as audit_shared_post;
import 'widgets/post_comments_draft_test.dart' as audit_comments_draft;
import 'core/diagnostics/app_logger_privacy_test.dart' as audit_logs;
import 'unit/authenticated_media_origin_test.dart' as audit_media_origin;
import 'widgets/expression_picker_test.dart' as expression_picker;
import 'unit/expression_editing_test.dart' as expression_editing;
import 'widgets/settings_refresh_test.dart' as settings_refresh;
import 'widgets/feed_features_test.dart' as feed_features;
import 'unit/settings_registry_test.dart' as settings_registry_navigation;
import 'unit/comment_thread_test.dart' as comment_threads;
import 'widgets/comment_item_test.dart' as comment_items;
import 'providers/post_comments_provider_test.dart' as comment_provider;
import 'notifications/notification_reliability_test.dart'
    as notification_reliability;
import 'widgets/call_media_hub_test.dart' as call_media_hub;
import 'widgets/web_settings_paste_test.dart' as web_settings_paste;
import 'services/call_sender_quality_test.dart' as call_sender_quality;
import 'widgets/bot_keyboard_feedback_test.dart' as bot_keyboard_feedback;
import 'widgets/web_workspace_test.dart' as web_workspace;
import 'core/network/web_socket_reliability_test.dart' as transport_reliability;
import 'widgets/message_surface_test.dart' as message_surfaces;
import 'providers/inbox_reliability_test.dart' as inbox_reliability;
import 'unit/message_preview_text_test.dart' as message_previews;
import 'services/mesh_preferences_test.dart' as mesh_preferences;
import 'widgets/neutral_inbox_test.dart' as neutral_inbox;
import 'unit/interactive_message_test.dart' as interactive_messages;
import 'providers/interactive_provider_test.dart' as interactive_provider;
import 'widgets/interactive_messages_test.dart' as interactive_widgets;
import 'services/mesh_automatic_access_test.dart' as mesh_access;
import 'services/mesh_permission_race_test.dart' as mesh_permission_race;
import 'services/ordinary_automatic_keys_test.dart' as ordinary_automatic_keys;
import 'widgets/ordinary_key_actions_test.dart' as ordinary_key_actions;
import 'services/bluetooth_mesh_test.dart' as bluetooth_mesh;
import 'services/bluetooth_mesh_delivery_test.dart' as bluetooth_delivery;
import 'services/automatic_enrollment_test.dart' as automatic_enrollment;
import 'widgets/ordinary_e2ee_settings_test.dart' as ordinary_e2ee_settings;
import 'services/ordinary_e2ee_test.dart' as ordinary_e2ee;
import 'widgets/message_bold_text_test.dart' as message_bold_text;
import 'unit/report_evidence_submission_test.dart'
    as report_evidence_submission;
import 'settings_plus_navigation_test.dart' as settings_plus_navigation;
import 'unit/incoming_app_route_test.dart' as incoming_app_route;
import 'plus_activation_screen_test.dart' as plus_activation_screen;
import 'plus_purchase_options_test.dart' as plus_purchase_options;
import 'unit/app_url_launcher_test.dart' as app_url_launcher;
import 'unit/plus_activation_link_test.dart' as plus_activation_link;
// Unified test suite aggregator for rapid single-pass compilation in CI.
import 'package:flutter_test/flutter_test.dart';

import 'unit/performance_lifecycle_regression_test.dart' as perf_lifecycle;
import 'unit/permission_service_test.dart' as contextual_permissions;
import 'unit/background_service_serialization_test.dart'
    as background_service_serialization;
import 'unit/update_asset_integrity_test.dart' as update_asset_integrity;
import 'unit/ota_update_artifact_state_test.dart' as ota_update_artifact_state;
import 'unit/e2ee_streaming_file_cipher_test.dart'
    as e2ee_streaming_file_cipher;
import 'unit/history_retention_test.dart' as history_retention;
import 'unit/encrypted_history_archive_test.dart' as encrypted_history_archive;
import 'unit/hive_bootstrap_account_cache_test.dart' as hive_account_cache;
import 'widgets/message_layout_store_test.dart' as message_layout_store;
import 'core/animated_media_budget_test.dart' as animated_media_budget;
import 'core/e2ee_file_pipeline_test.dart' as e2ee_file_pipeline;
import 'core/media_file_cache_pipeline_test.dart' as media_file_cache_pipeline;
import 'core/background_stream_crypto_test.dart' as background_stream_crypto;
import 'services/blob_upload_resources_test.dart' as blob_upload_resources;
import 'services/nios_protocol_accounts_test.dart' as protocol_accounts;
import 'services/nios_protocol_enrollment_test.dart' as protocol_enrollment;
import 'services/secret_stream_service_test.dart' as secret_stream_service;
import 'services/secret_stream_chat_delivery_test.dart'
    as secret_stream_delivery;
import 'services/secret_storage_performance_test.dart'
    as secret_storage_performance;
import 'services/secret_attachment_file_store_test.dart'
    as secret_attachment_file_store;
import 'providers/secret_attachment_file_delivery_test.dart'
    as secret_attachment_file_delivery;
import 'services/secret_engine_optimization_test.dart'
    as secret_engine_optimization;
import 'providers/secret_coordinator_lifecycle_test.dart'
    as secret_coordinator_lifecycle;
import 'unit/frame_timing_monitor_percentiles_test.dart' as frame_percentiles;
import 'perf/ui_smoothness_regression_guard_test.dart' as perf_logic_guards;
import 'perf/chat_performance_benchmarks_test.dart'
    as chat_algorithm_regressions;
import 'binary_packet_test.dart' as binary_packet;
import 'bots_inline_query_test.dart' as bots_inline_query;
import 'calls_gateway_limits_test.dart' as calls_gateway_limits;
import 'chat_list_m1_test.dart' as chat_list_m1;
import 'double_ratchet_test.dart' as double_ratchet;
import 'e2ee_file_crypto_test.dart' as e2ee_file_crypto;
import 'e2ee_safety_words_test.dart' as e2ee_safety_words;
import 'services/secret_chat_delivery_test.dart' as secret_chat_delivery;
import 'services/call_signaling_connection_test.dart'
    as call_signaling_connection;
import 'services/call_negotiation_test.dart' as call_negotiation;
import 'providers/incoming_call_delivery_test.dart' as incoming_call_delivery;
import 'services/secret_chat_e2ee_test.dart' as secret_chat_e2ee;
import 'widgets/secret_chat_ui_test.dart' as secret_chat_ui;
import 'widgets/m3_route_tab_switcher_test.dart' as route_tab_switcher;
import 'providers/ordinary_chat_realtime_test.dart' as ordinary_chat_realtime;
import 'widgets/appearance_palette_test.dart' as appearance_palette;
import 'widgets/app_modals_test.dart' as app_modals;
import 'widgets/app_startup_gate_test.dart' as app_startup_gate;
import 'widgets/app_toast_test.dart' as app_toast;
import 'unit/noto_emoji_test.dart' as noto_emoji;
import 'widgets/noto_message_emoji_test.dart' as noto_message_emoji;
import 'widgets/noto_picker_test.dart' as noto_picker;
import 'widgets/noto_visual_test.dart' as noto_visual;
import 'formatter_and_detector_test.dart' as formatter_and_detector;
import 'global_search_deep_links_test.dart' as global_search_deep_links;
import 'group_moderation_test.dart' as group_moderation;
import 'legal_viewer_screen_test.dart' as legal_viewer_screen;
import 'milestone2_adversarial_stress_test.dart'
    as milestone2_adversarial_stress;
import 'niosgram_media_reactions_test.dart' as niosgram_media_reactions;
import 'onboarding_screens_test.dart' as onboarding_screens;
import 'privacy_blocklist_test.dart' as privacy_blocklist;
import 'profile_schedule_badges_test.dart' as profile_schedule_badges;
import 'reports_support_spamblock_test.dart' as reports_support_spamblock;
import 'stickers_test.dart' as stickers;
import 'core/m3_spring_constants_test.dart' as core_m3_spring_constants;
import 'e2e/niosgram_and_settings_e2e_test.dart' as e2e_niosgram_and_settings;
import 'integration/e2e_auth_flow_test.dart' as integration_e2e_auth_flow;
import 'integration/e2e_cold_start_and_logout_test.dart'
    as integration_e2e_cold_start;
import 'models/chat_wallpaper_config_test.dart' as models_chat_wallpaper_config;
import 'screens/login_screen_test.dart' as screens_login_screen;
import 'screens/register_screen_test.dart' as screens_register_screen;
import 'unit/adaptive_performance_engine_test.dart'
    as unit_adaptive_performance_engine;
import 'unit/app_update_service_test.dart' as unit_app_update_service;
import 'unit/call_transport_test.dart' as unit_call_transport;
import 'unit/quic_transport_stub_test.dart' as unit_quic_transport_stub;
import 'unit/chat_creation_flow_test.dart' as unit_chat_creation_flow;
import 'unit/chat_media_cache_test.dart' as unit_chat_media_cache;
import 'unit/chat_message_sorting_test.dart' as unit_chat_message_sorting;
import 'unit/device_hardware_recognition_test.dart'
    as unit_device_hardware_recognition;
import 'unit/docx_parser_test.dart' as unit_docx_parser;
import 'unit/feed_and_stickers_cache_test.dart' as unit_feed_and_stickers_cache;
import 'unit/gallery_optimization_and_caching_test.dart'
    as unit_gallery_optimization_and_caching;
import 'unit/list_virtualization_memory_test.dart'
    as unit_list_virtualization_memory;
import 'unit/oauth_service_test.dart' as unit_oauth_service;
import 'unit/pkce_test.dart' as unit_pkce;
import 'unit/shared_media_classification_test.dart'
    as unit_shared_media_classification;
import 'unit/smooth_text_streamer_test.dart' as unit_smooth_text_streamer;
import 'unit/sound_service_test.dart' as unit_sound_service;
import 'unit/sticker_formatter_test.dart' as unit_sticker_formatter;
import 'unit/public_media_contract_test.dart' as unit_public_media_contract;
import 'widgets/video_avatar_test.dart' as widgets_video_avatar;
import 'unit/morphing_brand_mark_test.dart' as unit_morphing_brand_mark;
import 'unit/moments_test.dart' as unit_moments;
import 'unit/tri_sync_test.dart' as unit_tri_sync;
import 'unit/nios_link_and_blob_store_test.dart'
    as unit_nios_link_and_blob_store;
import 'widgets/adaptive_glass_test.dart' as widgets_adaptive_glass;
import 'm3e_design_audit_test.dart' as m3e_design_audit;
import 'widgets/chat_list_header_and_performance_test.dart'
    as widgets_chat_list_header;
import 'widgets/chat_wallpaper_painter_test.dart'
    as widgets_chat_wallpaper_painter;
import 'widgets/create_post_screen_test.dart' as widgets_create_post_screen;
import 'widgets/niosgram_feed_m3_test.dart' as widgets_niosgram_feed_m3;
import 'widgets/public_profile_and_grouped_gallery_test.dart'
    as widgets_public_profile_gallery;
import 'widgets/settings_about_screen_test.dart'
    as widgets_settings_about_screen;
import 'widgets/settings_desktop_restructure_test.dart'
    as widgets_settings_desktop_restructure;
import 'widgets/settings_master_detail_test.dart'
    as widgets_settings_master_detail;
import 'widgets/settings_screens_m3_test.dart' as widgets_settings_screens_m3;
import 'widgets/settings_scroll_smoothness_test.dart'
    as widgets_settings_scroll_smoothness;
import 'widgets/settings_system_device_test.dart'
    as widgets_settings_system_device;
import 'widgets/tab_shared_axis_switcher_test.dart'
    as widgets_tab_shared_axis_switcher;
import 'widgets/vector_illustrations_test.dart' as widgets_vector_illustrations;
import 'unit/m3_motion_kit_unit_test.dart' as unit_m3_motion_kit;
import 'widgets/m3_motion_kit_test.dart' as widgets_m3_motion_kit;

void main() {
  feed_features.main();
  comment_threads.main();
  comment_items.main();
  comment_provider.main();
  call_media_hub.main();
  group('Bluetooth encrypted fallback', () {
    mesh_preferences.main();
    mesh_access.main();
    mesh_permission_race.main();
    ordinary_automatic_keys.main();
    ordinary_key_actions.main();
    bluetooth_mesh.main();
    bluetooth_delivery.main();
  });
  ordinary_e2ee_settings.main();
  ordinary_e2ee.main();
  automatic_enrollment.main();
  message_bold_text.main();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aggregated Test Suite', () {
    group('notification_reliability', notification_reliability.main);
    group('app_startup_gate', app_startup_gate.main);
    group('app_toast', app_toast.main);
    group('noto_emoji', noto_emoji.main);
    group('noto_message_emoji', noto_message_emoji.main);
    group('noto_picker', noto_picker.main);
    group('noto_visual', noto_visual.main);
    group('protocol_accounts', protocol_accounts.main);
    group('protocol_enrollment', protocol_enrollment.main);
    group('background_stream_crypto', background_stream_crypto.main);
    group('secret_stream_service', secret_stream_service.main);
    group('secret_stream_delivery', secret_stream_delivery.main);
    // Core & Models
    core_m3_spring_constants.main();
    models_chat_wallpaper_config.main();

    // Unit Tests
    unit_adaptive_performance_engine.main();
    unit_app_update_service.main();
    unit_call_transport.main();
    unit_quic_transport_stub.main();
    unit_chat_creation_flow.main();
    unit_chat_media_cache.main();
    unit_chat_message_sorting.main();
    unit_device_hardware_recognition.main();
    unit_docx_parser.main();
    unit_feed_and_stickers_cache.main();
    unit_gallery_optimization_and_caching.main();
    unit_list_virtualization_memory.main();
    unit_oauth_service.main();
    unit_pkce.main();
    unit_shared_media_classification.main();
    unit_smooth_text_streamer.main();
    unit_sound_service.main();
    unit_sticker_formatter.main();
    unit_public_media_contract.main();
    widgets_video_avatar.main();
    unit_morphing_brand_mark.main();
    unit_moments.main();
    unit_tri_sync.main();
    unit_nios_link_and_blob_store.main();
    unit_m3_motion_kit.main();

    // Performance lifecycle, storage and resource regressions. No device FPS assertions.
    group('perf_lifecycle', perf_lifecycle.main);
    group('contextual_permissions', contextual_permissions.main);
    group(
      'background_service_serialization',
      background_service_serialization.main,
    );
    group('update_asset_integrity', update_asset_integrity.main);
    group('ota_update_artifact_state', ota_update_artifact_state.main);
    group('e2ee_streaming_file_cipher', e2ee_streaming_file_cipher.main);
    group('history_retention', history_retention.main);
    group('encrypted_history_archive', encrypted_history_archive.main);
    group('hive_account_cache', hive_account_cache.main);
    group('message_layout_store', message_layout_store.main);
    group('animated_media_budget', animated_media_budget.main);
    group('e2ee_file_pipeline', e2ee_file_pipeline.main);
    group('media_file_cache_pipeline', media_file_cache_pipeline.main);
    group('blob_upload_resources', blob_upload_resources.main);
    group('secret_storage_performance', secret_storage_performance.main);
    group('secret_attachment_file_store', secret_attachment_file_store.main);
    group(
      'secret_attachment_file_delivery',
      secret_attachment_file_delivery.main,
    );
    group('secret_engine_optimization', secret_engine_optimization.main);
    group('secret_coordinator_lifecycle', secret_coordinator_lifecycle.main);
    group('frame_percentiles', frame_percentiles.main);
    group('perf_logic_guards', perf_logic_guards.main);
    group('chat_algorithm_regressions', chat_algorithm_regressions.main);

    // Protocol & Logic Suites
    group('Call connection regression', call_signaling_connection.main);
    group('Call negotiation regression', call_negotiation.main);
    binary_packet.main();
    bots_inline_query.main();
    calls_gateway_limits.main();
    double_ratchet.main();
    e2ee_file_crypto.main();
    e2ee_safety_words.main();
    secret_chat_delivery.main();
    secret_chat_e2ee.main();
    secret_chat_ui.main();
    route_tab_switcher.main();
    ordinary_chat_realtime.main();
    interactive_messages.main();
    interactive_provider.main();
    interactive_widgets.main();
    appearance_palette.main();
    app_modals.main();
    formatter_and_detector.main();
    global_search_deep_links.main();
    group_moderation.main();
    milestone2_adversarial_stress.main();
    niosgram_media_reactions.main();
    privacy_blocklist.main();
    profile_schedule_badges.main();
    reports_support_spamblock.main();
    stickers.main();

    incoming_app_route.main();
    app_url_launcher.main();
    plus_activation_link.main();
    plus_activation_screen.main();
    plus_purchase_options.main();
    settings_plus_navigation.main();
    report_evidence_submission.main();

    // Screen & UI Widget Tests
    group('Incoming call regression', incoming_call_delivery.main);
    chat_list_m1.main();
    legal_viewer_screen.main();
    onboarding_screens.main();
    screens_login_screen.main();
    screens_register_screen.main();

    // Full-audit regressions keep each file's setup/teardown scoped.
    group('audit_emoji_forms', audit_emoji_forms.main);
    group('audit_app_lock', audit_app_lock.main);
    group('audit_auth', audit_auth.main);
    group('audit_drafts', audit_drafts.main);
    group('audit_accounts', audit_accounts.main);
    group('audit_send_fence', audit_send_fence.main);
    group('audit_emoji_lifecycle', audit_emoji_lifecycle.main);
    group('audit_feed_races', audit_feed_races.main);
    group('audit_post_media', audit_post_media.main);
    group('audit_shared_post', audit_shared_post.main);
    group('audit_comments_draft', audit_comments_draft.main);
    group('audit_logs', audit_logs.main);
    group('audit_media_origin', audit_media_origin.main);
    group('encrypted_draft_sync', encrypted_draft_sync.main);
    group('encrypted_draft_codec', encrypted_draft_codec.main);
    group('live_location', live_location.main);
    group('chat_extras', chat_extras.main);
    group('file_request', file_request.main);
    group('media_local_path_security', media_local_path_security.main);

    // Widgets
    expression_picker.main();
    expression_editing.main();
    neutral_inbox.main();
    message_surfaces.main();
    bot_keyboard_feedback.main();
    web_settings_paste.main();
    call_sender_quality.main();
    web_workspace.main();
    transport_reliability.main();
    inbox_reliability.main();
    message_previews.main();
    widgets_adaptive_glass.main();
    m3e_design_audit.main();
    widgets_chat_list_header.main();
    widgets_chat_wallpaper_painter.main();
    widgets_create_post_screen.main();
    widgets_niosgram_feed_m3.main();
    widgets_public_profile_gallery.main();
    settings_refresh.main();
    settings_registry_navigation.main();
    chat_productivity.main();
    widgets_settings_about_screen.main();
    widgets_settings_desktop_restructure.main();
    widgets_settings_master_detail.main();
    widgets_settings_screens_m3.main();
    widgets_settings_scroll_smoothness.main();
    widgets_settings_system_device.main();
    widgets_tab_shared_axis_switcher.main();
    widgets_vector_illustrations.main();
    widgets_m3_motion_kit.main();

    // End-to-End & Integration Suites
    e2e_niosgram_and_settings.main();
    integration_e2e_auth_flow.main();
    integration_e2e_cold_start.main();
  });
}
