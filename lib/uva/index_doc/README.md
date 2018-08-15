<!-- lib/uva/index_doc/README.md -->

# SolrDocument extension modules

Each of these modules mixes in to UVA::IndexDoc to extend its interface by
adding new methods and definitions which make the resulting document instance
capable of handling an additional type of data.

These are referred to as "SolrDocument" extensions because only instances of
SolrDocument (via Blacklight) will be able to make use of the full extension.
Other derivatives of UVA::IndexDoc (like UVA::ArticleDoc) only get the
extension's interface(methods ()which return blank results).

## Extension components

Each extension consists of a namespace module and, within that namespace, an
Interface module, an Extension module and possibly other modules used by the
Extension module.

```ruby
  module NamespaceForExtension
  
    # Injects NamespaceForExtension::Interface into the calling class/module.
    def self.included(base) # :nodoc:
      [Interface].each do |mod|
        base.send(:include, mod) unless base.include?(mod)
      end
    end

    module Interface
      def method1(arg1, *)  # Defines required args; ignores others; return nil
      end
    end
  
    module Extension
      include NamespaceForExtension # Inherit Interface definitions to override.
      def method1(arg1)     # Actual arguments.
        # ...               # Actual code returning a value.
      end
    end
  
  end
```

#### Namespace

The namespace module does not define any methods itself -- it's only
function is to include the extension's Interface module into a class that uses
the `include UVA::IndexDoc` statement.

(The Extension module also includes the namespace so that the namespace module
makes the Extension module inherit from Interface.)


#### <big>`Interface`</big>

The Interface module contains definitions of methods which return the
appropriate results for the case where the SolrDocument instance does *not*
represent an EAD. (Usually this is a `nil`, `false` or otherwise blank result.)

The methods here represent the interface definition for the extension module.
So, despite the fact that the methods return blank values, they are documented
with the `@params` and `@return` that the actual method needs (including
`@raise` documentation if the actual method may raise an exception).

This module also defines one method which can be used within the
`use_extension` block to indicate whether the full Extension should be mixed in
to the SolrDocument being initialized.  For example, in the case of UVA::Ead,
this is the `is_ead?` method -- other extension modules have similar methods.

#### <big>`Extension`</big>

The Extension module contains overrides of the Interface methods which perform
the actual operations of the extension.  If the logic for a method as defined
in the Interface module is already sufficient, the Extension module can refrain
from overriding that method.

One method that almost always should be overridden is the one that indicates
whether the extension should be included:  E.g., `UVA::Ead::Extension#is_ead?`
is defined to return `true`.

#### Other modules

Unlike Interface and Extension, other modules that might be in the extension
namespace should be self-contained logic that can be included independently in
other code, even if it does not "load" the extension.

For example, UVA::EAD::Xml contains definitions which are used in
UVA::Ead::Extension and are also used in Firehose.

## Usage

The `include UVA::IndexDoc` statement automatically includes the Interface
module of each extension from */lib/uva/index_doc*, so it's never necessary to
explicitly include any of the extensions.

SolrDocument must be modified to use the Blacklight `use_extension` method so
that the full Extension module will be included when a SolrDocument instance is
initialized if that extension is appropriate.  For UVA::Ead this is:
  
```ruby
  if include?(UVA::Ead)
    use_extension(UVA::Ead::Extension) do |doc|
      doc.is_ead?
    end
  end
```

Here the code guards against the possibility that */lib/uva/index_doc/ead.rb*
was not actually present; if it was then the SolrDocument instance should have
UVA::Ead::Interface methods mixed in at this point so that `is_ead?` can be
queried.  If it returns `true` then Blacklight will mix in UVA::Ead::Extension
before initialization of the SolrDocument instance is complete.

## Implementation Notes

Breaking with convention, although these modules live in */lib/uva/index_doc*
they are not in the UVA::IndexDoc namespace (that is, for example, `UVA::Ead`
and not `UVA::IndexDoc::Ead`).  This is in keeping with the original names,
although this might change in the future.

Note that all Interface definitions of all extension modules are mixed in to
the same place, so despite the fact that each extension module represents its
own (sub) namespace, methods need to be named uniquely so that they do not
clash with each other or with the methods already defined in UVA::IndexDoc or
SolrDocument.

---
---

> [![Blacklight][bl_img]][bl_url]
> Virgo is based on the [Blacklight][bl_url] [gem][bl_gem] for searching Solr indexes in Ruby-on-Rails.

> [![RubyMine][rm_img]][rm_url]
> Virgo developers use [RubyMine][rm_url] for better Ruby-on-Rails development.

<!---------------------------------------------------------------------------->
<!-- Other link references:
REF ---------- LINK ---------------------------- TOOLTIP --------------------->
[version_url]: https://github.com/uvalib/virgo
[version_img]: https://badge.fury.io/gh/uvalib%2virgo.png
[status_url]:  https://travis-ci.org/uvalib/virgo
[status_img]:  https://api.travis-ci.org/uvalib/virgo.svg?branch=develop
[bl_img]:      ../../doc/images/blacklight_logo.png
[bl_url]:      http://projectblacklight.org
[bl_gem]:      https://rubygems.org/gems/blacklight
[rm_img]:      ../../doc/images/icon_RubyMine.png
[rm_url]:      https://www.jetbrains.com/ruby

<!-- vi: set filetype=markdown: set wrap: -->
