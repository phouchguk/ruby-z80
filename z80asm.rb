#!/usr/bin/env ruby

# test we have a filename
puts "What file should I compile? Usage z80asm file_name" if ARGV.length == 0

def main
  org = -1 # throw an error if we start using jumps and we haven't got org
  line_nr = 0
  ip = 0
  code = []

  File.open(ARGV[0], "r") do |file|
    while(line = file.gets)
      line_nr += 1

      line.strip!
      line.downcase!
      
      # ignore comments and blank lines
      next if line.start_with?("#") or line.empty?
      
      # deal with org line
      if line.start_with?("org")
        parts = line.split(" ")
        if parts.length != 2
          throw "Must be org and a memory address i.e. org 30000"
        else
          org = hex_or_int(parts[1])
        end 
       
        next
      end

      # deal wth labels
      if line.end_with?(":")
        next # deal with this later
      end

      # parse instruction
      parts = line.split(",").map(&:strip)
      nr_parts = parts.length
      res = nil

      case nr_parts
      when 1
        res = instr_single(parts[0])
      when 2
        # is the second part an argument or part of a single instruction i.e. LD A,B
        if ["a", "b", "bc", "c", "d", "de", "e", "h", "hl", "l"].include?(parts[1])
          res = instr_single(parts.join(",")) # remove whitespace
        else
          res = instr_double(parts[0], parts[1])
        end
      end

      if res.kind_of?(Array)
        ip += res.length
        code += res            
      else
        code << res
        ip += 1
      end
    end
  end

  #puts code.map{|x| x.to_s(16).rjust(2, '0')}.join(" ")
  print code.pack("C*")
end

# nr must be an int
def double_hex(nr)
  if nr < 256
    [ nr, 0 ]
  else
    [ nr % 256, nr / 256 ]
  end
end

def hex_or_int(str)
  if str.start_with?("0x") 
    str[2, str.length - 1].to_i(16)
  elsif str.end_with?("h")
    str[0, str.length - 1].to_i(16)
  elsif str.index(/[abcdef]/)
    str.to_i(16)
  else
    str.to_i
  end
end

def instr_double(instr, arg)
  if arg.start_with?("[") && arg.end_with?("]")
    throw "can't deal with mem addressing yet"
  else
    nr = hex_or_int(arg)
    case instr
    when "add a" : [ 0xc6, single_hex(nr) ]
    when "adc a" : [ 0xce, single_hex(nr) ]
    when "ld a" : [ 0x3e, single_hex(nr) ]
    when "ld b" : [ 0x06, single_hex(nr) ]
    when "ld bc"
      res = [ 0x01 ]
      res += double_hex(nr)
    when "ld c" : [ 0x0e, single_hex(nr) ]
    when "ld d" : [ 0x16, single_hex(nr) ]
    when "ld de"
      res = [ 0x11 ]
      res += double_hex(nr)
    when "ld e" : [ 0x1e, single_hex(nr) ]
    when "ld h" : [ 0x26, single_hex(nr) ]
    when "ld hl"
      res = [ 0x21 ]
      res += double_hex(nr)
    when "ld l" : [ 0x2e, single_hex(nr) ]
    when "sbc a" : [ 0xde, single_hex(nr) ]
    when "sub" : [ 0xd6, single_hex(nr) ]
    end
  end
end

def instr_single(instr)
  case instr
    when "adc a,a" : 0x8f
    when "adc a,b" : 0x88
    when "adc a,c" : 0x89
    when "adc a,d" : 0x8a
    when "adc a,e" : 0x8b
    when "adc a,h" : 0x8c
    when "adc a,l" : 0x8d
    when "adc hl,bc" : [ 0xed, 0x4a ]
    when "adc hl,de" : [ 0xed, 0x5a ]
    when "adc hl,hl" : [ 0xed, 0x6a ]
    when "add a,a" : 0x87
    when "add a,b" : 0x80
    when "add a,c" : 0x81
    when "add a,d" : 0x82
    when "add a,e" : 0x83
    when "add a,h" : 0x84
    when "add a,l" : 0x85
    when "add hl,bc" : 0x09
    when "add hl,de" : 0x19
    when "add hl,hl" : 0x29
    when "ccf" : 0x3f
    when "dec a" : 0x3d
    when "dec b" : 0x05
    when "dec bc" : 0x0b
    when "dec c" : 0x0d
    when "dec d" : 0x15
    when "dec de" : 0x1b
    when "dec e" : 0x1d
    when "dec h" : 0x25
    when "dec hl" : 0x2b
    when "dec l" : 0x2d
    when "inc a" : 0x3c
    when "inc b" : 0x04
    when "inc bc" : 0x03
    when "inc c" : 0x0c
    when "inc d" : 0x14
    when "inc de" : 0x13
    when "inc e" : 0x1c
    when "inc h" : 0x24
    when "inc hl" : 0x23
    when "inc l" : 0x2c
    when "ld a,a" : 0x7f
    when "ld a,b" : 0x78
    when "ld a,c" : 0x79
    when "ld a,d" : 0x7a
    when "ld a,e" : 0x7b
    when "ld a,h" : 0x7c
    when "ld a,l" : 0x7d
    when "ld b,a" : 0x47
    when "ld b,b" : 0x40
    when "ld b,c" : 0x41
    when "ld b,d" : 0x42
    when "ld b,e" : 0x43
    when "ld b,h" : 0x44
    when "ld b,l" : 0x45
    when "ld c,a" : 0x4f
    when "ld c,b" : 0x48
    when "ld c,c" : 0x49
    when "ld c,d" : 0x4a
    when "ld c,e" : 0x4b
    when "ld c,h" : 0x4c
    when "ld c,l" : 0x4d
    when "ld d,a" : 0x57
    when "ld d,b" : 0x50
    when "ld d,c" : 0x51
    when "ld d,d" : 0x52
    when "ld d,e" : 0x53
    when "ld d,h" : 0x54
    when "ld d,l" : 0x55
    when "ld e,a" : 0x5f
    when "ld e,b" : 0x58
    when "ld e,c" : 0x59
    when "ld e,d" : 0x5a
    when "ld e,e" : 0x5b
    when "ld e,h" : 0x5c
    when "ld e,l" : 0x5d
    when "ld h,a" : 0x67
    when "ld h,b" : 0x60
    when "ld h,c" : 0x61
    when "ld h,d" : 0x62
    when "ld h,e" : 0x63
    when "ld h,h" : 0x64
    when "ld h,l" : 0x65
    when "ld l,a" : 0x6f
    when "ld l,b" : 0x68
    when "ld l,c" : 0x69
    when "ld l,d" : 0x6a
    when "ld l,e" : 0x6b
    when "ld l,h" : 0x6d
    when "ld l,l" : 0x6e
    when "ret" : 0xc9
    when "sbc a,a" : 0x9f
    when "sbc a,b" : 0x98
    when "sbc a,c" : 0x99
    when "sbc a,c" : 0x9a
    when "sbc a,e" : 0x9b
    when "sbc a,h" : 0x9c
    when "sbc hl,bc" : [ 0xed, 0x42 ]
    when "sbc hl,de" : [ 0xed, 0x52 ]
    when "sbc hl,hl" : [ 0xed, 0x62 ]
    when "sbc l" : 0x9d
    when "scf" : 0x37
    when "sub a" : 0x97
    when "sub b" : 0x90
    when "sub c" : 0x91
    when "sub d" : 0x92
    when "sub e" : 0x93
    when "sub h" : 0x94
    when "sub l" : 0x95
  else
    throw "Unrecognised instruction #{instr}"
  end
end

def parse_label(line)

end

def parse_org(line)
  org = -1

  if line.start_with?("org")
    got_org = true
    parts = line.split(" ")
    if parts.length != 2
      puts "Must be org and a memory address i.e. org 30000"
      [false, org]
    else
      org = parts[1].to_i
      [true, org]
    end
  else
    puts "I need to know first up where in memory the program is going to be loaded i.e. org 30000."
    [false, org]
  end
end

def single_hex(nr)
  throw "#{nr} is too big.  Must be < 256." unless nr < 256
  nr
end

main()

#c = [ 0x01, 0x2a, 0x00 ]
#print c.pack("C*")

#org 30000


