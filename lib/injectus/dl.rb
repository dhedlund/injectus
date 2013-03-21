require 'dl'
require 'fiddle'

class RubyVM
  class InstructionSequence
    address = DL::Handle::DEFAULT['rb_iseq_load']
    func = Fiddle::Function.new(address, [DL::TYPE_VOIDP] * 3, DL::TYPE_VOIDP)

    define_singleton_method(:load_a) do |data, parent = nil, opt = nil|
      func.call(DL.dlwrap(data), parent, opt).to_value
    end

    define_singleton_method(:load_file) do |fname, parent = nil, opt = nil|
      load_a File.open(fname, 'rb') {|f| Marshal.load(file) }
    end

  end
end
