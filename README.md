LastTweet
=========

A horrible, hacky application to grab the last tweet from a given Twitter account and print it to the console.

It is a total mess, it's all in one file, it mixes Strings, lazy ByteStrings, strict ByteStrings and some horrible Unicode regex garbage.

To run this file, you need a local file called "application.properties" which is the Java-style properties: key=value. You need three keys:

  * twitter.account: The Twitter handle (without the @) you are querying
  * twitter.key: Your personal Twitter API key
  * twitter.secret: Your personal Twitter API secret

This avoids OAuth2 by using Twitter's [Application-only Authentication](https://dev.twitter.com/docs/auth/application-only-auth).

TODO
====

In no order, or any idea if I'll ever do any of it:

  * Make the code nicer
  * Sort out all the string mess
  * Integrate with OAuth2 and perhaps allow use of the twitter username/password for auth
  * Fix the issues with character encoding
  * Break out the properties into its own library. I cannot find a simple key=value property lookup in Haskell. Unless I'm doing it wrong?
