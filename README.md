<!-- README.md -->

# Virgo
<!-- [![GitHub version][version_img]][version_url] -->

Virgo is a library search-and-discovery system based on [Blacklight][bl_url]
which provides an interface for searching a Solr index containing records from
the UVa Library catalog (Sirsi/Dynix Unicorn), local Fedora repositories, and
other metadata sources.

| Directory                                        | Description                         |
|--------------------------------------------------|-------------------------------------|
| [app][app]                                       | Rails MVC framework                 |
| [app/assets][assets]                             | - Images, CSS, JavaScript           |
| [app/controllers/concerns][concerns]             | - Controller concerns               |
| [app/helpers][helpers]                           | - View helpers                      |
| [lib][lib]                                       | UVA classes and extensions          |
| [config][config], [db][db]                       | Configuration, database and startup |
| [public][public]                                 | Web service home directory          |
| [script][script]                                 | Scripts and executables             |
| [features][features], [spec][spec], [test][test] | Automated testing support           |

## Installation

> _**NOTE**: these instructions were copied from the original "README.textile"
and have not yet been updated._

###### -

VIRGO requires:

| Gem             | Verify with       |
|-----------------|-------------------|
| Ruby 1.9.3-p547 | `ruby --version`  |
| Rubygems 2.2.2  | `gem --version`   |
| Rake 10.3.2     | `rake --version`  |
| Rails 3.1.10    | `rails --version` |

To install VIRGO, clone it, run bundler, then start it:

```sh
git clone git@github.com:uvalib/virgo.git
bundle install
```

You'll need to have `mysql` running somewhere and set up a database to use.
For the default database settings, please see `config/database.yml` in the
stanza for _**development**_ settings. Feel free to change the development
database settings if you like, but don't commit the changes.

Here's an example of setting up the database:

```sh
mysql -u root -p
  # (enter your password)
```
```mysql
create database blacklight_development;
grant all on blacklight_development.* to some_username@localhost identified by 'some_password';
```

Now that your database has been configured, you can run the migrations to load
the tables and start your application:

```sh
rake db:migrate
rails server
```

You should now be able to access the application at `http://localhost:3000`.

To run the tests, set up a test database and user in the same way you did for
development above, but use the _**test**_ settings as defined in
`config/database.yml`, then do the migrations for the test environment:

```sh
rake RAILS_ENV=test db:migrate
```

Then do the following from the command line:

```sh
bundle exec rspec spec/
```

For the cucumber tests:

```sh
bundle exec cucumber features/
```

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Directory link references used above:
REF --------- LINK -------------------------- TOOLTIP ------------------------>
[app]:         app/README.md                      "Rails MVC framework"
[config]:      config/README.md                   "Configuration and startup"
[db]:          db/README.md                       "Database classes and setup"
[doc]:         doc/README.md                      "Documentation placeholder"
[features]:    features/README.md                 "Feature-level testing"
[lib]:         lib/README.md                      "UVA classes and extensions"
[public]:      public/README.md                   "Web service home directory"
[script]:      script/README.md                   "Scripts and executables"
[spec]:        spec/README.md                     "Unit-level testing"
[test]:        test/README.md                     "Test fixtures and support"
[assets]:      app/assets/README.md               "Images, CSS, JavaScript"
[concerns]:    app/controllers/concerns/README.md "Controller concerns"
[helpers]:     app/helpers/README.md              "View helpers"

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF --------- LINK -------------------------- TOOLTIP ------------------------>
[version_url]: https://github.com/uvalib/virgo
[version_img]: https://badge.fury.io/gh/uvalib%2virgo.png
[status_url]:  https://travis-ci.org/uvalib/virgo
[status_img]:  https://api.travis-ci.org/uvalib/virgo.svg?branch=develop
[bl_img]:      lib/doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      lib/doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
