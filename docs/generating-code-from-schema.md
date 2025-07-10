The DGS Code Generation plugin generates code during your project’s build process based on your Domain Graph Service’s GraphQL schema file.
The plugin generates the following:

* Data types for types, input types, enums and interfaces.
* A `DgsConstants` class containing the names of types and fields
* A type safe query API that represents your queries

## Quick Start

Code generation is typically integrated in the build.
This project provides a Gradle plugin, and a Maven plugin was made [available](https://github.com/deweyjose/graphqlcodegen) by the community, built on the same core.

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
   generateClient = true // Enable generating the type safe query API
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
Please ensure that your project’s sources refer to the generated code using the specified package name.

You can exclude parts of the schema from code-generation by placing them in a different schema directory that is not specified<!-- http://go/pv --> as part of the `schemaPaths` for the plugin.

### Using the generated types

The generated types are POJOs with both a non-arg constructor, a constructor for all fields, and implementations for hashCode/equals/toString.
You also get a builder class to easily create instances.
The types are typically used used as return types for your datafetchers and input arguments for your datafetchers. 

The following are some examples of using generated types for the example schema below.

```graphql
type Query {
    events: [Event]
}

type Event {
    id: ID
    name: String
    location: String
    keywords: [String]
    website: String
    date: Date
}

type Mutation {
    update(event: EventInput): String
}

input EventInput {
    id: ID
    name: String
    location: String
    keywords: [String]
    website: String
    date: Date
}
```

```java
@DgsQuery
public List<Event> events() {
    return List.of(
            Event.newBuilder()
                    .name("JavaOne")
                    .location("Redwood City")
                    .build()
    );
}

@DgsMutation
public String update(@InputArgument EventInput event) {
    LOGGER.info("Storing event: {}", event.getName());
    
    return "Stored event with id " + event.getId();
}
```

### Sparse updates

Use the `trackInputFieldSet` flag to enable tracking which fields are set on input types.
This is useful for sparse updates; just sending the fields in a mutation that you want to update, and leave other fields untouched.
Codegen creates the POJOs with each field value wrapped in an `Optional`, and a `has[FieldName]` method to check if the optional was set.
In a mutation datafetcher you can check the input type for which fields were explicitly set.

```groovy
generateJava {
    trackInputFieldSet = true
}
```

```java
@DgsMutation
public String update(@InputArgument EventInput event) {

    LOGGER.info("Storing event: {}", event.getName());

    var updated = new HashSet<String>();

    if(event.hasName()) {
        LOGGER.info("Update name to: {}", event.getName());
        updated.add("name=" + event.getName());
    }

    if(event.hasLocation()) {
        LOGGER.info("Update location to: {}", event.getLocation());
        updated.add("location=" + event.getLocation());
    }

    if(event.hasWebsite()) {
        LOGGER.info("Update website to: {}", event.getWebsite());
        updated.add("website=" + event.getWebsite());
    }

    if(event.hasDate()) {
        LOGGER.info("Update date to: {}", event.getDate());
        updated.add("date=" + event.getDate());
    }

    if(event.hasKeywords()) {
        LOGGER.info("Update keywords to: {}", event.getKeywords());
        updated.add("keywords=" + event.getKeywords());
    }

    return String.join(", ", updated);

}
```

<div style="position: relative; padding-bottom: 55.55555555555556%; height: 0;"><iframe src="https://www.loom.com/embed/b41be952bfc3466d84e0cc8a07760a1d?sid=b4ff9f10-a2c8-4a8a-b6d7-379e13008e0a" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen style="position: absolute; top: 0; left: 0; width: 100%; height: 100%;"></iframe></div>

## Generating code from external schemas in JARs
You can also specify external dependencies containing schemas to use for generation by declaring it as a dependency in the `dgsCodegen` configuration.
The plugin will scan all `.graphql` and `.graphqls` files and generate those classes under the `build/generated` directory.
This is useful if you have external dependencies containing some shared types that you want to add to your schema for code generation. 
Not that this does NOT affect your project's schema, and is only for code generation.

```groovy
dependencies {
    // other dependencies
    dgsCodegen 'com.netflix.graphql.dgs:example-schema:x.x.x'
}
```

For libraries that are looking to export [type mappings](#mapping-existing-types) for their schemas (see next section), you can also add a `dgs.codegen.typemappings` file as a resource under META-INF.
For a project that is consuming schemas from an external JAR, codegen will also scan `dgs.codegen.typemappings` to automatically map types to corresponding Java classes.
This avoids the need to explicitly specify type mappings by every consumer of the JAR.

## Mapping existing types

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

The code generator can also create client API classes.
You can use these classes to query data from a GraphQL endpoint using Java, or in unit tests using the `DgsQueryExecutor`.
The Java GraphQL Client is useful for server-to-server communication.
A GraphQL Java Client is [available](advanced/java-client.md) as part of the framework.

Code generation creates a <code><var>field-name</var>GraphQLQuery</code> for each Query and Mutation field.
The <code>\*GraphQLQuery</code> query class contains fields for each parameter of the field.
For each type returned by a Query or Mutation, code generation creates a <code>\*ProjectionRoot</code>.
A projection is a builder class that specifies which fields get returned.

The following is an example usage of a generated API.

```graphql
type Query {
    events(filter: EventFilter): [Event]
}

input EventFilter {
    name: String
    location: String
}

type Event {
    id: ID
    name(uppercase: Boolean): String
    location: String
    keywords: [String]
    website: String
}
```

```java
@SpringBootTest(classes = QueryDatafetcher.class)
@EnableDgsTest
class QueryDatafetcherTest {

    @Autowired
    DgsQueryExecutor queryExecutor;

    @Test
    public void clientApi() {
        var query = EventsGraphQLQuery.newRequest()
                .queryName("ExampleQuery")
                .filter(EventFilter.newBuilder().name("JavaOne").build())
                .build();

        var projection = new EventsProjectionRoot<>().name(true).parent().location();
        var request = new GraphQLQueryRequest(query, projection);

        var serializeQuery = request.serialize();
        var result = queryExecutor.execute(serializeQuery);

        System.out.println(serializeQuery);
        assertThat(result.isDataPresent()).isTrue();
    }

}
```

Creating a query has three parts:
1. The query - `EventsGraphQLQuery` in this example, generated by Codegen. 
2. The projection (the fields you want to retrieve) - `EventsProjectionRoot` in this example, generated by Codegen.
3. The `GraphQLQueryRequest` which is part of the DGS API.

The `GraphQLQueryRequest` lets you `serialize()`, which gives the String representation of the request.
For this example this results in the following request.

```graphql
query ExampleQuery {
    events(filter: {name : "JavaOne"}) {
        name(uppercase: true)
        location
    }
}
```

### Using query variables
In the previous examples the input arguments to the query (the  `filter`), and the input argument to the `name` field (`uppercase`) where provided in-line.
This is the easiest way to write a query and has the benefit of the arguments being typed.
However, creating queries this way can come with a downside.
Advanced GraphQL features such as persisted queries require queries to be written with variables.
This is a bit more cumbersome because you lose typing, but it's sometimes required.
Codegen creates `[fieldName]Reference` and `[fieldName]WithVariableReferences` (for projections) for this purpose.

The following is an example of the same query as above, but with using variables.

```java
@SpringBootTest(classes = QueryDatafetcher.class)
@EnableDgsTest
class QueryDatafetcherTest {

    @Autowired
    DgsQueryExecutor queryExecutor;

    @Test
    public void clientApi() {
        var query = EventsGraphQLQuery.newRequest()
                .queryName("ExampleQuery")
                .filterReference("eventFilter")
                .build();

        var projection = new EventsProjectionRoot<>()
                .nameWithVariableReferences("uppercase").parent()
                .location();

        var request = new GraphQLQueryRequest(query, projection);

        var serializeQuery = request.serialize();
        var result = queryExecutor.execute(serializeQuery,
                Map.of("eventFilter", Map.of("name", "JavaOne"),
                        "uppercase", true));

        System.out.println(serializeQuery);
        assertThat(result.isDataPresent()).isTrue();
    }

}
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
}
```
Firstly, you can specify exactly which queries/mutation/subscriptions to generate for via `includeQueries`, `includeMutations`, and `includeSubscriptions`.
`skipEntityQueries` is only used if you are constructing federated `_entities` queries for testing purposes, so you can also set that to restrict the amount of generated code.

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
While using ```@deprecated``` following configuration is needed
```
generateJava {
    addDeprecatedAnnotation = true
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

| Configuration property            | Description                                                                                                                                                                                 | Default Value                                         |
|-----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| schemaPaths                       | List of files/directories containing schemas                                                                                                                                                | src/main/resources/schema                             |
| packageName                       | Base package name of generated code                                                                                                                                                         |                                                       |
| subPackageNameClient              | Sub package name for generated Query API                                                                                                                                                    | client                                                |
| subPackageNameDatafetchers        | Sub package name for generated data fetchers                                                                                                                                                | datafetchers                                          |
| subPackageNameTypes               | Sub package name for generated data types                                                                                                                                                   | types                                                 |
| language                          | Either `java` or `kotlin`                                                                                                                                                                   | Autodetected from project                             |
| typeMapping                       | A Map where each key is a GraphQL type, and the value the FQN of a Java class                                                                                                               |                                                       |
| generateBoxedTypes                | Always use boxed types for primitives                                                                                                                                                       | false (boxed types are used only for nullable fields) |
| generateClient                    | Generate a Query API. This property does the same thing as generateClientv2.                                                                                                                | false                                                 |
| generateClientv2                  | Generate a Query API. This property does the same thing as generateClient.                                                                                                                  | false                                                 |
| generateDataTypes                 | Generate data types. Useful for only generating a Query API. Input types are still generated when `generateClientv2` is true.                                                               | true                                                  |
| generateInterfaces                | Generate interfaces for data classes. This is useful if you would like to extend the generated POJOs for more context and use interfaces instead of the data classes in your data fetchers. | false                                                 |
| generatedSourcesDir               | Build directory for Gradle                                                                                                                                                                  | build                                                 |
| includeQueries                    | Generate Query API only for the given list of Query fields                                                                                                                                  | All queries defined in schema                         |
| includeMutations                  | Generate Query API only for the given list of Mutation fields                                                                                                                               | All mutations defined in schema                       |
| includeSubscriptions              | Generate Query API only for the given list of Subscription fields                                                                                                                           | All subscriptions defined in schema                   |
| skipEntityQueries                 | Disable generating Entity queries for federated types                                                                                                                                       | false                                                 |
| shortProjectionNames              | Shorten class names of projection types. These types are not visible to the developer.                                                                                                      | false                                                 |
| includeImports                    | Maps the custom annotation type to the package, the annotations belong to. Only used when generateCustomAnnotations is enabled.                                                             |                                                       |
| includeEnumImports                | Maps the custom annotation and enum argument names to the enum packages. Only used when generateCustomAnnotations is enabled.                                                               |                                                       |
| includeClassImports               | Maps the custom annotation and class names to the class packages. Only used when generateCustomAnnotations is enabled.                                                                      
| generateCustomAnnotations         | Enable/disable generation of custom annotation                                                                                                                                              | false                                                 |
| addGeneratedAnnotation            | Add `jakarta.annotation.Generated` and application specific `@Generated` annotation to generated types                                                                                      | false                                                 |
| disableDatesInGeneratedAnnotation | Don't add a date to the `jakarta.annotation.Generated` annotation                                                                                                                           | false                                                 |
| trackInputFieldSet                | Generate `has[FieldName]` methods keeping track of what fields are explicitly set on input types                                                                                            | false                                                 |
