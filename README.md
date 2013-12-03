This repository contains code used while experimenting with YARV bytecode
precompilation under the MRI ruby interpreter.  For larger rails projects,
a considerable portion of load time during development is spent preloading
gems and other dependencies that almost never change unless bundler's
Gemfile changes.  Even though the MRI interpreter can read and write YARV
instruction sequences, it does not expose all interfaces publicly.

**This is a work in [un]progress**.  This code is known to NOT WORK with
`rbenv`, but the reason is currently unknown.  It _should_ work with
`rvm`, but assumes you do not prefix your commands with `bundle ...`
(for now).  It is not currently being maintained due to reasons outlined
in the "Practice" section of this README.


## Theory
In theory, it should be possible to create a library that wraps a series of
`require` statements in an application (or bundler itself) and builds one
large precompiled blob of bytecode that can later be injected on subsequent
invocations.  When that same block of code is reached, instead of executing
the contents of that block, a blob of bytecode is injected into the YARV VM
and the `$LOADED_FEATURES` list is updated.  The original source files would
never be parsed and the MRI interpreter would have to re-navigate a possibly
gigantic dependency graph.

```ruby
#!/usr/bin/env ruby

require 'injectus'

Injectus.capture do
  require 'bundler'
  Bundler.require(:default)
end
```


## Practice
In practice, there are multiple tools that try to inject themselves into
the code loading process, including both bundler and rails.  To complicate
thing further, ruby has a concept of `autoload` (lazy evaluation of
dependencies) and rails 3 also implements their own variation of autoload
via ActiveSupport::Dependencies.

### Autoload
With the MRI interpreter (at least the 1.9.x series), `require` statements
defined in ruby code can be reliably captured, including the order in which
source files are interpreted.  Due to legacy issues, ruby code loaded
through `autoload` does not call back out to the ruby's `require`, contrary
to expectation and has not been fixed in 1.9.x or early 2.0.x releases:
* http://blade.nagaokaut.ac.jp/cgi-bin/vframe.rb/ruby/ruby-core/20190?20151-20712

Because we can not reliably get a list of all files required in their
original order, it is not possible to capture and reload instructions as
one giant blob; instead it requires us to manage code loading one source
file at a time, and to keep track of whether any other source files have
been loaded between invocations of `require`.

One positive is that autoloading in both ruby and rails appear to be on
their way out due to issues with thread-safety, see:
* https://www.ruby-forum.com/topic/3036681
* http://bugs.ruby-lang.org/issues/921
* http://blog.plataformatec.com.br/2012/08/eager-loading-for-greater-good/

### Bytecode Injection
MRI provides an interface for accessing instruction sequences via
`RubyVM::InstructionSequence`.  It does not provide a public interface for
loading those sequences back into the VM from within ruby code.  This can
be worked around by exposing `rb_iseq_load` ourselves using ruby's `DL`
module (http://www.ruby-doc.org/stdlib-2.0.0/libdoc/dl/rdoc/DL.html).

Unfortunately, unmarshalling bytecode into ruby objects before passing it
back to the YARV VM causes a major performance hit due to garbage collection
and boxing of data structures _(some speculation here)_.  The end result is
only a marginal performance increase that is further eroded in newer
versions of MRI (1.9.3) that make additional improvements in code loading
(http://www.rubyinside.com/ruby-1-9-3-faster-loading-times-require-4927.html).

### Future Viability
This could be a viable project if it was possible to
* reliably track the load order of all source files compiled into instruction sequences
* load a bytecode sequence directly into the VM without first unmarshalling into ruby objects


## Resources
Primary Resources:
* http://www.ruby-doc.org/core-1.9.2/RubyVM/InstructionSequence.html
* https://groups.google.com/forum/?fromgroups=#!topic/ruby-core-google/05-jMqhJApI
* http://www.atdot.net/yarv/
* http://www.atdot.net/yarv/yarvarch.en.html

Other links that may be useful:
* https://www.ruby-forum.com/topic/205612
* http://archive.germanforblack.com/articles/ruby-autoload
* http://blog.jacius.info/ruby-c-extension-cheat-sheet/
* http://timetobleed.com/the-broken-promises-of-mrireeyarv/
* https://gumroad.com/l/iDDV
* http://tenderlovemaking.com/2011/12/05/profiling-rails-startup-with-dtrace.html
