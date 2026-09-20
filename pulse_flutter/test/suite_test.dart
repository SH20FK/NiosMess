// Unified test suite aggregator for rapid single-pass compilation in CI.
import 'package:flutter_test/flutter_test.dart';

import 'binary_packet_test.dart' as binary_packet;
import 'bots_inline_query_test.dart' as bots_inline_query;
import 'calls_gateway_limits_test.dart' as calls_gateway_limits;
import 'chat_list_m1_test.dart' as chat_list_m1;
import 'double_ratchet_test.dart' as double_ratchet;
import 'e2ee_file_crypto_test.dart' as e2ee_file_crypto;
import 'e2ee_safety_words_test.dart' as e2ee_safety_words;
import 'formatter_and_detector_test.dart' as formatter_and_detector;
import 'global_search_deep_links_test.dart' as global_search_deep_links;
import 'group_moderation_test.dart' as group_moderation;
import 'legal_viewer_screen_test.dart' as legal_viewer_screen;
import 'milestone2_adversarial_stress_test.dart' as milestone2_adversarial_stress;
import 'niosgram_media_reactions_test.dart' as niosgram_media_reactions;
import 'onboarding_screens_test.dart' as onboarding_screens;
import 'privacy_blocklist_test.dart' as privacy_blocklist;
import 'profile_schedule_badges_test.dart' as profile_schedule_badges;
import 'reports_support_spamblock_test.dart' as reports_support_spamblock;
import 'stickers_test.dart' as stickers;
import 'core/m3_spring_constants_test.dart' as core_m3_spring_constants;
import 'e2e/niosgram_and_settings_e2e_test.dart' as e2e_niosgram_and_settings;
import 'integration/e2e_auth_flow_test.dart' as integration_e2e_auth_flow;
import 'integration/e2e_cold_start_and_logout_test.dart' as integration_e2e_cold_start;
import 'models/chat_wallpaper_config_test.dart' as models_chat_wallpaper_config;
import 'screens/login_screen_test.dart' as screens_login_screen;
import 'screens/register_screen_test.dart' as screens_register_screen;
import 'unit/adaptive_performance_engine_test.dart' as unit_adaptive_performance_engine;
import 'unit/app_update_service_test.dart' as unit_app_update_service;
import 'unit/call_transport_test.dart' as unit_call_transport;
import 'unit/chat_creation_flow_test.dart' as unit_chat_creation_flow;
import 'unit/chat_media_cache_test.dart' as unit_chat_media_cache;
import 'unit/chat_message_sorting_test.dart' as unit_chat_message_sorting;
import 'unit/device_hardware_recognition_test.dart' as unit_device_hardware_recognition;
import 'unit/docx_parser_test.dart' as unit_docx_parser;
import 'unit/feed_and_stickers_cache_test.dart' as unit_feed_and_stickers_cache;
import 'unit/gallery_optimization_and_caching_test.dart' as unit_gallery_optimization_and_caching;
import 'unit/list_virtualization_memory_test.dart' as unit_list_virtualization_memory;
import 'unit/oauth_service_test.dart' as unit_oauth_service;
import 'unit/pkce_test.dart' as unit_pkce;
import 'unit/shared_media_classification_test.dart' as unit_shared_media_classification;
import 'unit/sound_service_test.dart' as unit_sound_service;
import 'unit/sticker_formatter_test.dart' as unit_sticker_formatter;
import 'unit/morphing_brand_mark_test.dart' as unit_morphing_brand_mark;
import 'unit/moments_test.dart' as unit_moments;
import 'unit/tri_sync_test.dart' as unit_tri_sync;
import 'unit/nios_link_and_blob_store_test.dart' as unit_nios_link_and_blob_store;
import 'widgets/adaptive_glass_test.dart' as widgets_adaptive_glass;
import 'm3e_design_audit_test.dart' as m3e_design_audit;
import 'widgets/chat_list_header_and_performance_test.dart' as widgets_chat_list_header;
import 'widgets/chat_wallpaper_painter_test.dart' as widgets_chat_wallpaper_painter;
import 'widgets/create_post_screen_test.dart' as widgets_create_post_screen;
import 'widgets/niosgram_feed_m3_test.dart' as widgets_niosgram_feed_m3;
import 'widgets/public_profile_and_grouped_gallery_test.dart' as widgets_public_profile_gallery;
import 'widgets/settings_about_screen_test.dart' as widgets_settings_about_screen;
import 'widgets/settings_desktop_restructure_test.dart' as widgets_settings_desktop_restructure;
import 'widgets/settings_master_detail_test.dart' as widgets_settings_master_detail;
import 'widgets/settings_screens_m3_test.dart' as widgets_settings_screens_m3;
import 'widgets/settings_scroll_smoothness_test.dart' as widgets_settings_scroll_smoothness;
import 'widgets/settings_system_device_test.dart' as widgets_settings_system_device;
import 'widgets/tab_shared_axis_switcher_test.dart' as widgets_tab_shared_axis_switcher;
import 'widgets/vector_illustrations_test.dart' as widgets_vector_illustrations;
import 'unit/m3_motion_kit_unit_test.dart' as unit_m3_motion_kit;
import 'widgets/m3_motion_kit_test.dart' as widgets_m3_motion_kit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Aggregated Test Suite', () {
    // Core & Models
    core_m3_spring_constants.main();
    models_chat_wallpaper_config.main();

    // Unit Tests
    unit_adaptive_performance_engine.main();
    unit_app_update_service.main();
    unit_call_transport.main();
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
    unit_sound_service.main();
    unit_sticker_formatter.main();
    unit_morphing_brand_mark.main();
    unit_moments.main();
    unit_tri_sync.main();
    unit_nios_link_and_blob_store.main();
    unit_m3_motion_kit.main();

    // Protocol & Logic Suites
    binary_packet.main();
    bots_inline_query.main();
    calls_gateway_limits.main();
    double_ratchet.main();
    e2ee_file_crypto.main();
    e2ee_safety_words.main();
    formatter_and_detector.main();
    global_search_deep_links.main();
    group_moderation.main();
    milestone2_adversarial_stress.main();
    niosgram_media_reactions.main();
    privacy_blocklist.main();
    profile_schedule_badges.main();
    reports_support_spamblock.main();
    stickers.main();

    // Screen & UI Widget Tests
    chat_list_m1.main();
    legal_viewer_screen.main();
    onboarding_screens.main();
    screens_login_screen.main();
    screens_register_screen.main();

    // Widgets
    widgets_adaptive_glass.main();
    m3e_design_audit.main();
    widgets_chat_list_header.main();
    widgets_chat_wallpaper_painter.main();
    widgets_create_post_screen.main();
    widgets_niosgram_feed_m3.main();
    widgets_public_profile_gallery.main();
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
