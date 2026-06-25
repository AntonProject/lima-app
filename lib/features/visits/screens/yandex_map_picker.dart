import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/i18n/app_i18n.dart';
import '../../../core/theme/app_theme.dart';

/// Result of picking a point on the Yandex map.
class MapPickResult {
  final LatLng point;
  final String address;
  const MapPickResult(this.point, this.address);
}

/// Full-screen Yandex map (WebView + JS API) for picking a location.
/// The pin is fixed at the screen centre; the map pans under it and the
/// address is reverse-geocoded from the point under the pin — same behaviour
/// as the web form.
class YandexMapPicker extends StatefulWidget {
  final LatLng initial;

  const YandexMapPicker({super.key, required this.initial});

  @override
  State<YandexMapPicker> createState() => _YandexMapPickerState();
}

class _YandexMapPickerState extends State<YandexMapPicker> {
  late final WebViewController _controller;
  LatLng _center = const LatLng(41.311081, 69.240562);
  String _address = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _center = widget.initial;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'PointChannel',
        onMessageReceived: _onPointMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      // baseUrl = the web domain the Yandex key is registered for, so the
      // map/geocoder requests carry a matching referer/origin and aren't
      // rejected by the key's domain restriction.
      ..loadHtmlString(
        _html(widget.initial),
        baseUrl: 'https://agent.lima.uz',
      );
  }

  void _onPointMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final lat = (data['lat'] as num).toDouble();
      final lng = (data['lng'] as num).toDouble();
      final addr = (data['address'] as String?) ?? '';
      if (!mounted) return;
      setState(() {
        _center = LatLng(lat, lng);
        _address = addr;
      });
    } catch (_) {}
  }

  String _html(LatLng c) {
    final key = EnvConfig.yandexMapsApiKey;
    final keyParam = key.isEmpty ? '' : 'apikey=$key&';
    // Pin is a fixed DOM element at the centre; on every map move we geocode
    // the centre and post {lat,lng,address} back to Flutter.
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
  <style>
    html, body, #map { margin:0; padding:0; width:100%; height:100%; }
    #pin {
      position: fixed; left: 50%; top: 50%;
      transform: translate(-50%, -100%);
      z-index: 1000; pointer-events: none;
      width: 40px; height: 40px;
    }
    #pin svg { width: 40px; height: 40px; }
  </style>
  <script src="https://api-maps.yandex.ru/2.1/?${keyParam}lang=ru_RU"></script>
</head>
<body>
  <div id="map"></div>
  <div id="pin">
    <svg viewBox="0 0 24 24" fill="#E3494B" xmlns="http://www.w3.org/2000/svg">
      <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 110-5 2.5 2.5 0 010 5z"/>
    </svg>
  </div>
  <script>
    function send(center) {
      ymaps.geocode(center).then(function (res) {
        var obj = res.geoObjects.get(0);
        var addr = obj ? obj.getAddressLine() : '';
        PointChannel.postMessage(JSON.stringify({
          lat: center[0], lng: center[1], address: addr
        }));
      }, function () {
        PointChannel.postMessage(JSON.stringify({
          lat: center[0], lng: center[1], address: ''
        }));
      });
    }
    ymaps.ready(function () {
      var map = new ymaps.Map('map', {
        center: [${c.latitude}, ${c.longitude}],
        zoom: 16,
        controls: ['zoomControl', 'geolocationControl']
      }, {
        // Drag to pan + pinch/scroll/double-click to zoom around the point.
        behaviors: ['drag', 'multiTouch', 'dblClickZoom', 'scrollZoom']
      });
      send(map.getCenter());
      var t = null;
      map.events.add('boundschange', function () {
        if (t) clearTimeout(t);
        t = setTimeout(function () { send(map.getCenter()); }, 400);
      });
      // Tap anywhere: recentre the map on that point (the pin stays centred,
      // so it ends up exactly where the user tapped) and re-geocode.
      map.events.add('click', function (e) {
        var coords = e.get('coords');
        map.panTo(coords, { flying: true, duration: 250 });
      });
    });
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          // Address preview chip at the top.
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: shadowSm,
              ),
              child: Text(
                _address.isEmpty ? context.l10n.t('tapMapToPick') : _address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(context.l10n.t('cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    MapPickResult(_center, _address),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: Text(context.l10n.t('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
