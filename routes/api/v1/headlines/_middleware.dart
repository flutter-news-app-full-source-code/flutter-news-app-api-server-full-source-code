import 'package:dart_frog/dart_frog.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authentication_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/middlewares/authorization_middleware.dart';
import 'package:flutter_news_app_api_server_full_source_code/src/registry/model_registry.dart';

Handler middleware(Handler handler) {
  return handler
      .use(
        (handler) => (context) {
          final modelConfig = modelRegistry['headline']!;
          return handler(
            context
                .provide<ModelConfig<dynamic>>(() => modelConfig)
                .provide<String>(() => 'headline'),
          );
        },
      )
      .use(authorizationMiddleware())
      .use(requireAuthentication());
}
