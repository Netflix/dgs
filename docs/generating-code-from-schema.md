The DGS Code Generation plugin generates code during your project’s build process based on your Domain Graph Service’s GraphQL schema file.
The plugin generates the following:

* Data types for types, input types, enums and interfaces.
* A `DgsConstants` class containing the names of types and fields
* Example data fetchers
* A type safe query API that represents your queries

## Quick Start

Code generation is typically integrated in the build.
A Gradle plugin has always been available, and recently a Maven plugin was made [available](https://github.com/deweyjose/graphqlcodegen) by the community.

To apply the plugin, update your project’s `build.gradle` file to include the following:
```groovy
// Using plugins DSL
plugins {
	id "com.netflix.dgs.codegen" version "[REPLACE_WITH_CODEGEN_PLUGIN_VERSION]"
}
```

Alternatively, you can set up classpath dependencies in your buildscript:
```groovy
buildscript {
   dependencies{
      classpath 'com.netflix.graphql.dgs.codegen:graphql-dgs-codegen-gradle:[REPLACE_WITH_CODEGEN_PLUGIN_VERSION]'
   }
}

apply plugin: 'com.netflix.dgs.codegen'
```

Next, you need to add the task configuration as shown here:

```groovy
generateJava{
   schemaPaths = ["${projectDir}/src/main/resources/schema"] // List of directories containing schema files
   packageName = 'com.example.packagename' // The package name to use to generate sources
   generateClientv2 = true // Enable generating the type safe query API
}
```

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
 NOTE: Please use the latest version of the plugin, available <a href="https://github.com/Netflix/dgs-codegen/releases">here</a>
</div>

The plugin adds a `generateJava` Gradle task that runs as part of your project’s build.
`generateJava` generates the code in the project’s `build/generated` directory.
Note that on a Kotlin project, the `generateJava` task generates Kotlin code by default (yes the name is confusing).
This folder is automatically added to the project's classpath.
Types are available as part of the package specified by the <code><var>packageName</var>.types</code>, where you specify the value of <var>packageName</var> as a configuration in your `build.gradle` file.
Please ensure that your project’s sources refer to the generated code using<!-- http://go/pv http://go/use --> the specified package name.

`generateJava` generates the data fetchers and places them in `build/generated-examples`.

<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
 NOTE: generateJava does NOT add the data fetchers that it generates to your project’s sources.
 These fetchers serve mainly as a basic boilerplate code that require further implementation from you.
</div>

You can exclude parts of the schema from code-generation by placing them in a different schema directory that is not specified<!-- http://go/pv --> as part of the `schemaPaths` for the plugin.

### Fixing the "Could not initialize class graphql.parser.antlr.GraphqlLexer" problem

Gradle's plugin system uses a flat classpath for all plugins, which makes it very easy to run into classpath conflicts.
One of the dependencies of the Codegen plugin is ANTLR, which is unfortuanatly used by some other plugins as well.
If you see an error such as `Could not initialize class graphql.parser.antlr.GraphqlLexer` this typically indicates a classpath conflict.
If this happens, please change the ordering of the plugins in your build script.
ANTLR is typically backwards, but not forwards, compatible.

For multi-module projects means you need to declare the Codegen plugin in the root build file, without applying it:

```groovy
plugins {
    id("com.netflix.dgs.codegen") version "[REPLACE_WITH_CODEGEN_PLUGIN_VERSION]" apply false
    
    //other plugins
}
```

In the module where the plugin should be applied, you specify the plugin in the plugins block again, but without the version.

```groovy
plugins {
    id("com.netflix.dgs.codegen")
}
```

If you're using the old `buildscript` syntax, you add the plugin dependency to the root `buildscript`, but only `apply` in the module.

### Generating code from external schemas in JARs
You can also specify external dependencies containing schemas to use for generation by declaring it as a dependency in the `dgsCodegen` configuration.
The plugin will scan all `.graphql` and `.graphqls` files and generate those classes under the same `build/generated` directory.
This is useful if you have external dependencies containing some shared types that you want to add to your schema for code generation. 
Not that this does NOT affect your project's schema, and is only for code generation.

```groovy
dependencies {
    // other dependencies
    dgsCodegen 'com.netflix.graphql.dgs:example-schema:x.x.x'
}
```


### Mapping existing types

Codegen tries to generate a type for each type it finds in the schema, with a few exceptions.

1. Basic scalar types - are mapped to corresponding Java/Kotlin types (String, Integer etc.)
2. Date and time types - are mapped to corresponding `java.time` classes
3. PageInfo and RelayPageInfo - are mapped to `graphql.relay` classes
4. Types mapped with a `typeMapping` configuration

When you have existing classes that you want to use instead of generating a class for a certain type, you can configure the plugin to do so using a `typeMapping`.
The `typeMapping` configuration is a `Map` where each key is a GraphQL type and each value is a fully qualified Java/Kotlin type.

```groovy
generateJava{
   typeMapping = ["MyGraphQLType": "com.mypackage.MyJavaType"]
}
```

## Generating Client APIs
<div style="padding: 15px; border: 1px solid transparent; border-color: transparent; margin-bottom: 20px; border-radius: 4px; color: #8a6d3b;; background-color: #fcf8e3; border-color: #faebcc;">
NOTE: There is a new API for generating client APIs. The old generateClient will be deprecated soon. <a href="#generateclientv2">See more here</a>
</div>

The code generator can also create client API classes.
You can use these classes to query data from a GraphQL endpoint using Java, or in unit tests using the `QueryExecutor`.
The Java GraphQL Client is useful for server-to-server communication.
A GraphQL Java Client is [available](advanced/java-client.md) as part of the framework.

Code generation creates a <code><var>field-name</var>GraphQLQuery</code> for each Query and Mutation field.
The <code>\*GraphQLQuery</code> query class contains fields for each parameter of the field.
For each type returned by a Query or Mutation, code generation creates a <code>\*ProjectionRoot</code>.
A projection is a builder class that specifies which fields get returned.

The following is an example usage of a generated API:

```java
GraphQLQueryRequest graphQLQueryRequest =
        new GraphQLQueryRequest(
            new TicksGraphQLQuery.Builder()
                .first(first)
                .after(after)
                .build(),
            new TicksConnectionProjectionRoot()
                .edges()
                    .node()
                        .date()
                        .route()
                            .name()
                            .votes()
                                .starRating()
                                .parent()
                            .grade());

```

This API was generated based on the following schema.
The `edges` and `node` types are because the schema uses pagination.
The API allows for a fluent style of writing queries, with almost the same feel of writing the query as a String, but with the added benefit of code completion and type safety.

```graphql
type Query @extends {
    ticks(first: Int, after: Int, allowCached: Boolean): TicksConnection
}

type Tick {
    id: ID
    route: Route
    date: LocalDate
    userStars: Int
    userRating: String
    leadStyle: LeadStyle
    comments: String
}

type Votes {
    starRating: Float
    nrOfVotes: Int
}

type Route {
    routeId: ID
    name: String
    grade: String
    style: Style
    pitches: Int
    votes: Votes
    location: [String]
}

type TicksConnection {
    edges: [TickEdge]
}

type TickEdge {
    cursor: String!
    node: Tick
}
```

### generateClientv2

There is a new API for generating client API. To turn on the new version, use the ```generateClientv2``` Gradle configuration option. Note that the v1 API will be deprecated soon. 

This new version relies on the use of generics and solves:
1) Not being able to handle cycles in the schema, and
2) Not being able to generate on larger schemas due to too many classes getting generated and out of memory errors. We only generate one class per type in the new implementation.

The projection root needs to be instantiated differently for the v2 API.

v1 API:
```java
String query = new GraphQLQueryRequest(
        new MoviesGraphQLQuery(),
        new MoviesProjectionRoot().movieId()).serialize();
```

v2 API:
```java
String query = new GraphQLQueryRequest(
        new MoviesGraphQLQuery(),
        new MoviesProjectionRoot<>().movieId()).serialize();
```

### Generating Query APIs for external services

Generating a Query API like above is very useful for testing your own DGS.
The same type of API can also be useful when interacting with another GraphQL service, where your code is a client of that service.
This is typically done using the [DGS Client](https://netflix.github.io/dgs/advanced/java-client/).

When you use code generation both for your own schema, and an internal schema, you might want different code generation configuration for both.
The recommendation is to create a separate module in your project containing the schema of the external service and the codegen configuration to just generate a Query API.
The following is example configuration that _only_ generates a Query API.

```groovy
generateJava {
    schemaPaths = ["${projectDir}/composed-schema.graphqls"]
    packageName = "some.other.service"
    generateClientv2 = true
    generateDataTypes = false
    skipEntityQueries = true
    includeQueries = ["hello"]
    includeMutations = [""]
    shortProjectionNames = true
    maxProjectionDepth = 2
}
```

### Limiting generated code for Client API
If your schema is large or has a lot of cycles, it is not ideal to generate client APIs for the entire schema, since you will end up with a large number of projections.
This can cause code generation to slow down significantly, or run out of memory depending on your schema.
We have a few configuration parameters that help tune this so you can limit the generation of client API to only what is required.

```groovy
generateJava {
    ...
    generateClientv2 = true
    skipEntityQueries = true
    includeQueries = ["hello"]
    includeMutations = [""]
    includeSubscriptions = [""]
    maxProjectionDepth = 2
}
```
Firstly, you can specify exactly which queries/mutation/subscriptions to generate for via `includeQueries`, `includeMutations`, and `includeSubscriptions`.
`skipEntityQueries` is only used if you are constructing federated `_entities` queries for testing purposes, so you can also set that to restrict the amount of generated code.
Finally, `maxProjectionDepth` will instruct codegen to stop generating beyond 2 levels of the graph from the query root.
The default is 10.
This will help further limit the number of projections as well.

### Generating classes with Custom Annotations
This feature provides the ability to support any custom annotation on the generated POJOs using the @annotate directive in graphQL.
The `@annotate` directive can be placed on type, input or fields in the graphQL. This feature is turned off by default and can be enabled by setting generateCustomAnnotation to true in build.gradle.

```groovy
generateJava {
    ...
    generateCustomAnnotations = true
}
```
@annotate contains 4 fields:

* name - Mandatory field. Name of the annotation. Eg: ValidPerson. You can have the package along with the annotation name. eg: `com.test.ValidPerson`. The package value given with the annotation name takes precedence over the mapped package in build.gradle.
* type - Optional field. This variable is used to map the annotation package in build.gradle. The package if given with annotation name will take precedence over this value. But if neither are given an empty string is used.
* inputs - Optional field. Contains the inputs to the annotation in key-value pairs. Eg: `inputs: {types: [HUSBAND, WIFE]}`. Inputs can be of types: String, int, float, enums, list, map, class, etc. For class inputs, refer to *Example with Class Object* 
* target - Optional field. Refers to the site targets for the annotations. Refer to [use target site doc](https://kotlinlang.org/docs/annotations.html#annotation-use-site-targets) for the target site available values.

@annotate definition in the graphQL:
```
"Custom Annotation"
directive @annotate(
    name: String!
    type: String
    inputs: JSON
    target: String
) repeatable on OBJECT | FIELD_DEFINITION | INPUT_OBJECT | INPUT_FIELD_DEFINITION
```
Custom annotations specified in the schema will require corresponding implementations by the resolvers to avoid runtime errors.
Some examples:
```
type Person @annotate(name: "ValidPerson", type: "validator", inputs: {types: [HUSBAND, WIFE]}) {
       name: String @annotate(name: "com.test.anotherValidator.ValidName")
       type: String @annotate(name: "ValidType", type: "personType", inputs: {types: [PRIMARY, SECONDARY]}) 
}
```
The package mapping for the annotation and enums can be provided in the build.gradle file.
```groovy
generateJava {
    ...
    generateCustomAnnotations = true
    includeImports = ["validator": "com.test.validator"]
    includeEnumImports = ["ValidPerson": ["types": "com.enums"]]
}
```
Generated POJO in Java. **Please note that this feature is also available in Kotlin.**
```
package com.netflix.graphql.dgs.codegen.tests.generated.types;

import com.test.anotherValidator.ValidName;
import com.test.validator.ValidPerson;
import java.lang.Object;
import java.lang.Override;
import java.lang.String;

@ValidPerson(
    types = [com.enums.HUSBAND, com.enums.WIFE]
)
public class Person {
  @ValidName
  private String name;

  @ValidType(
      types = [com.personType.enum.PRIMARY, com.personType.enum.SECONDARY]
  )
  private String type;

  public Person() {
  }

  public Person(String name, String type) {
    this.name = name;
    this.type = type;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  public String getType() {
    return type;
  }

  public void setType(String type) {
    this.type = type;
  }

  @Override
  public String toString() {
    return "Person{" + "name='" + name + "'," +"type='" + type + "'" +"}";
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Person that = (Person) o;
        return java.util.Objects.equals(name, that.name) &&
                            java.util.Objects.equals(type, that.type);
  }

  @Override
  public int hashCode() {
    return java.util.Objects.hash(name, type);
  }
}
```

Example with Class Object:

Since GraphQL parser does not have built-in support for class objects, a class is represented as a string ending with ".class" in the schema

```
type Person @annotate(name: "ValidPerson", type: "validator", inputs: {groups: "BasicValidation.class"}) {
    name: String @annotate(name: "com.test.anotherValidator.ValidName")
}
```
The package mapping for the annotation and classes can be provided in the build.gradle file. If mapping is not provided, input will be treated as a string.

```groovy
generateJava {
    ...
    generateCustomAnnotations = true,
    includeImports = mapOf(Pair("validator", "com.test.validator")),
    includeClassImports = mapOf("ValidPerson" to mapOf(Pair("BasicValidation", "com.test.validator.groups")))
}
```
Generated POJO in Java. *Note: In Kotlin, using the same schema above will generate `BasicValidation::class`*
```
package com.netflix.graphql.dgs.codegen.tests.generated.types;

import com.test.anotherValidator.ValidName;
import com.test.validator.ValidPerson;
import com.test.validator.groups.BasicValidation;
import java.lang.Object;
import java.lang.Override;
import java.lang.String;

@ValidPerson(
    groups = BasicValidation.class
)
public class Person {
  @ValidName
  private String name;

  public Person() {
  }

  public Person(String name) {
    this.name = name;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  @Override
  public String toString() {
    return "Person{" + "name='" + name + "'" +"}";
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Person that = (Person) o;
        return java.util.Objects.equals(name, that.name);
  }

  @Override
  public int hashCode() {
    return java.util.Objects.hash(name);
  }
}
```

Example with target site:
```
type Person @deprecated(reason: "This is going bye bye") @annotate(name: "ValidPerson", type: "validator", inputs: {types: [HUSBAND, WIFE]}) {
    name: String @annotate(name: "com.test.anotherValidator.ValidName", target: "field") @annotate(name: "com.test.nullValidator.NullValue")
}
```
Generated POJO in Java.
```
package com.netflix.graphql.dgs.codegen.tests.generated.types;

import com.test.anotherValidator.ValidName;
import com.test.nullValidator.NullValue;
import com.test.validator.ValidPerson;
import java.lang.Deprecated;
import java.lang.Object;
import java.lang.Override;
import java.lang.String;

/**
 * This is going bye bye
 */
@Deprecated
@ValidPerson(
    types = [com.enums.HUSBAND, com.enums.WIFE]
)
public class Person {
  @ValidName
  @NullValue
  private String name;

  public Person() {
  }

  public Person(String name) {
    this.name = name;
  }

  public String getName() {
    return name;
  }

  public void setName(String name) {
    this.name = name;
  }

  @Override
  public String toString() {
    return "Person{" + "name='" + name + "'" +"}";
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Person that = (Person) o;
        return java.util.Objects.equals(name, that.name);
  }

  @Override
  public int hashCode() {
    return java.util.Objects.hash(name);
  }
}
```

# Configuring code generation

Code generation has many configuration switches.
The following table shows the Gradle configuration options, but the same options are available command line and in Maven as well.

| Configuration property   | Description                                                                                                                                                                                 | Default Value |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ----------- |
| schemaPaths              | List of files/directories containing schemas                                                                                                                                                | src/main/resources/schema |
| packageName              | Base package name of generated code                                                                                                                                                         | |
| subPackageNameClient     | Sub package name for generated Query API                                                                                                                                                    | client |
| subPackageNameDatafetchers | Sub package name for generated data fetchers                                                                                                                                                | datafetchers |
| subPackageNameTypes      | Sub package name for generated data types                                                                                                                                                   | types |
| language                 | Either `java` or `kotlin`                                                                                                                                                                   | Autodetected from project |
| typeMapping              | A Map where each key is a GraphQL type, and the value the FQN of a Java class                                                                                                               |  |
| generateBoxedTypes       | Always use boxed types for primitives                                                                                                                                                       | false (boxed types are used only for nullable fields) |
| generateClient           | Generate a Query API. This is version 1 of the API, which will be deprecated soon.                                                                                                          | false |
| generateClientv2         | Generate a Query API. This is version 2 of the API.                                                                                                                                         | false |
| generateDataTypes        | Generate data types. Useful for only generating a Query API. Input types are still generated when `generateClientv2` is true.                                                               | true |
| generateInterfaces       | Generate interfaces for data classes. This is useful if you would like to extend the generated POJOs for more context and use interfaces instead of the data classes in your data fetchers. | false |
| generatedSourcesDir      | Build directory for Gradle                                                                                                                                                                  | build |
| includeQueries           | Generate Query API only for the given list of Query fields                                                                                                                                  | All queries defined in schema |
| includeMutations         | Generate Query API only for the given list of Mutation fields                                                                                                                               | All mutations defined in schema |
| includeSubscriptions     | Generate Query API only for the given list of Subscription fields                                                                                                                           | All subscriptions defined in schema |
| skipEntityQueries        | Disable generating Entity queries for federated types                                                                                                                                       | false |
| shortProjectionNames     | Shorten class names of projection types. These types are not visible to the developer.                                                                                                      | false |
| maxProjectionDepth       | Maximum projection depth to generate. Useful for (federated) schemas with very deep nesting                                                                                                 | 10 |
| includeImports           | Maps the custom annotation type to the package, the annotations belong to. Only used when generateCustomAnnotations is enabled.                                                             |                                                       |
| includeEnumImports       | Maps the custom annotation and enum argument names to the enum packages. Only used when generateCustomAnnotations is enabled.                                                               |                                                       |
| includeClassImports      | Maps the custom annotation and class names to the class packages. Only used when generateCustomAnnotations is enabled.                                                                      
| generateCustomAnnotations | Enable/disable generation of custom annotation                                                                                                                                              | false                                                 | 
