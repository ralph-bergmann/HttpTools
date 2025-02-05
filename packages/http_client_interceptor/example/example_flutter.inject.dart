// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'example_flutter.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;
import 'package:http/src/client.dart' as _i3;
import 'package:flutter/src/foundation/key.dart' as _i4;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({required _i1.ApiModule apiModule}) =>
      MainComponent$Component._(apiModule);

  MainComponent$Component._(this._apiModule) {
    _initialize();
  }

  final _i1.ApiModule _apiModule;

  late final _Client$Provider _client$Provider;

  late final _MyAppFactory$Provider _myAppFactory$Provider;

  void _initialize() {
    _client$Provider = _Client$Provider(_apiModule);
    _myAppFactory$Provider = _MyAppFactory$Provider(_client$Provider);
  }

  @override
  _i1.MyAppFactory get appFactory => _myAppFactory$Provider.get();
}

class _Client$Provider implements _i2.Provider<_i3.Client> {
  _Client$Provider(this._module);

  final _i1.ApiModule _module;

  _i3.Client? _singleton;

  @override
  _i3.Client get() => _singleton ??= _module.provideHttpClient();
}

class _MyAppFactory$Provider implements _i2.Provider<_i1.MyAppFactory> {
  _MyAppFactory$Provider(this._client$Provider);

  final _Client$Provider _client$Provider;

  late final _i1.MyAppFactory _factory =
      _MyAppFactory$Factory(_client$Provider);

  @override
  _i1.MyAppFactory get() => _factory;
}

class _MyAppFactory$Factory implements _i1.MyAppFactory {
  const _MyAppFactory$Factory(this._client$Provider);

  final _Client$Provider _client$Provider;

  @override
  _i1.MyApp create({_i4.Key? key}) => _i1.MyApp(
        key: key,
        httpClient: _client$Provider.get(),
      );
}
