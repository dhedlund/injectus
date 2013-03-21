require 'injectus/dl'

module Injectus
  class YarvSequence
    def self.load_file(fname)
      self.new RubyVM::InstructionSequence.compile_file(fname)
    end

    def initialize(ins_seq)
      @ins_seq = ins_seq
    end

    def disassemble
      @ins_seq.disassemble
    end

    def to_a
      @ins_seq_a ||= @ins_seq.to_a
    end
  end
end
