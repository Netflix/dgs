
[Spring Boot] at Netflix supports serving<!-- http://go/pv --> static assets with [Meechum] integration<!-- http://go/pv --> out-of-the-box.
The [DGS] framework leverages this mechanism and so you can use<!-- http://go/use --> it to host web apps, if you need to do this in addition to implementing a [GraphQL] API.
The following sections describe how to set up a create-react-app for test, production, and local development.

## Test and Production

The DGS, by default, will serve any static assets in `resources/public`.
If your app and the DGS reside in the same repository, one approach is for you to integrate the steps for building your app and copying them<!-- "them" is ambiguous here --> to `resources/public` within your Rocket CI script:

```shell
cd ./react-app-dir && newt exec yarn run build && cd ..
cp -r ./react-app-dir/build/ src/main/resources/public
```

After you deploy the DGS you can access your deployed app on port 8443.
Note that this does not require the app to set up the authorization header to access the `/graphql` endpoint, since Spring Boot apps are already integrated with Meechum.

!!!note
    If you choose to use a different backend for serving static assets, you will need to set up [Meechum authentication](http://manuals.netflix.net/view/meechum/mkdocs/master/) in your React app. 

## Local Development

If you want to run your react app locally by executing `yarn start` or `npm start`, and you want to avoid building and copying the app to `/resources/public`, you will need to explictly set up Meechum authentication.

On the DGS, you will need a CORS filter that allows requests from a host that is different from your DGS:

```java
@Configuration
public class LocalHostSecurityConfig {
    private static final Logger LOGGER = LoggerFactory.getLogger(LocalHostSecurityConfig.class);

    @Bean
    public FilterRegistrationBean corsFilter() {
        LOGGER.info("Setting up custom CORS");
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        CorsConfiguration config = new CorsConfiguration();
        config.addAllowedOrigin("http://localhost:3000"); // yarn start
        config.addAllowedOrigin("https://localhost:8444"); // meego
        config.addAllowedHeader("Accept");
        config.addAllowedHeader("Content-Type");
        config.addAllowedHeader("X-Requested-With");
        config.addAllowedHeader("Authorization");
        config.addAllowedMethod("GET");
        config.addAllowedMethod("POST");
        config.addAllowedMethod("OPTIONS");
        source.registerCorsConfiguration("/**", config);
        FilterRegistrationBean bean = new FilterRegistrationBean(new CorsFilter(source));
        return bean;
    }
}
```

On the client side, you will need to set up the following:

- Add `meechum-user-lib-js` as a dependency by setting up your `.npmrc` or `.yarnc` with `registry = https://repo.test.netflix.net/artifactory/api/npm/npm-netflix`.

- Use the following snippet to set up Meechum authentication in your app:

         await MeechumUser.initialize(
           '/meechum',
           900,
           () => console.warn('Warning: Meechum session timed out'),
           () => console.error(`Error: Refreshing meechum token failed`));
         const token = Meechum.getUserToken();

    You can now use<!-- http://go/use --> the token and can set that<!-- "that" is ambiguous here --> in your authorization header for the request to `/graphql` endpoint.

- Run [meego](https://manuals.netflix.net/view/meechum/mkdocs/master/container/meego-proxy/).
  This will proxy your request to your local node server.
  For example:

        meego -listenPort 8444 -proxyTarget http://localhost:3000 -clientId yourEdwardPolicyClientId -clientSecret yourEdwardPolicyClientSecret
    
- You can now start your react app by executing `yarn start` or `npm start` as usual.
  Your app can make requests to the `/graphql` endpoint on the DGS.

This allows the developer to update the UI without having to restart the DGS each time, in cases where the DGS also serves static assets.

--8<-- "docs/reference_links"

