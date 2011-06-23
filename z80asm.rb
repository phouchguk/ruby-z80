#!/usr/bin/env ruby

# test we have a filename
puts "What file should I compile? Usage z80asm file_name" if ARGV.length == 0

$regs = ["a", "af", "b", "bc", "c", "d", "de", "e", "h", "hl", "l", "sp"]
$sfxs = ["nz", "z", "nc", "c", "po", "pe", "p", "m"]

def main
  org = -1 # throw an error if we start using jumps and we haven't got org
  line_nr = 0
  ip = 0
  code = []
  labels = {} # label is key to a ip location
  vars = {}
  rel_addrs = {} # relative address locations - label is key to array if ips
  abs_addrs = {} # absolute address locations - label is key to array if ips

  File.open(ARGV[0], "r") do |file|
    while(line = file.gets)
      line_nr += 1

      # strip comments
      cmd, comment = line.split(";")
      
      cmd.strip!

      # ignore blank cmds
      next if cmd.empty?

      # log variables
      if cmd.start_with?("$")
        parts = cmd.split(" ").map(&:strip)
        vars[parts[0]] = parts[1]
        next
      end

      # variable substitution
      vars.keys.each do |var|
        cmd.sub!(var, vars[var])
      end

      cmd.downcase!

      # deal with org line
      if cmd.start_with?("org")
        parts = cmd.split(" ")
        if parts.length != 2
          throw "Must be org and a memory address i.e. org 30000"
        else
          org = hex_or_int(parts[1])
        end 
       
        next
      end

      # log label locations (current ip, points to instruction after this one)
      if cmd.start_with?(":")
        labels[extract_label(cmd)] = ip
        next
      end

      # check for label references
      if include_label_ref?(cmd)
        if cmd.start_with?("jp")
          
        elsif cmd.start_with?("jr")
          
        else
          throw "only jp* and jr* commands can contain label references"
        end
      end

      # parse instruction
      parts = cmd.split(",").map(&:strip)
      nr_parts = parts.length
      res = nil

      # check for 'single' cmds with a numeric arg i.e. cp 32h
      # ignore anything with any addressing in first part of cmd
      if !include_addr?(parts[0])
        sub_parts = parts[0].split(" ").map(&:strip)
        if sub_parts.length > 1
          # check if not reg or cmd suffix
          if !$regs.include?(sub_parts[1]) && !$sfxs.include?(sub_parts[1])
            parts[0] = sub_parts[0]
            parts[1] = sub_parts[1]
            nr_parts = 2
          end
        end
      end

      # check for label references
      if include_label_ref?(parts[0])
        throw "only command args can contain label references"
      end

      if parts[1] && include_label_ref?(parts[1])
        lbl = extract_label(parts[1])
        if parts[0].start_with?("jp") || parts[0].start_with?("call") 
          abs_addrs[lbl] ||= []
          abs_addrs[lbl] << ip
        elsif parts[0].start_with?("jr")
          rel_addrs[lbl] ||= []
          rel_addrs[lbl] << ip
        else
          throw "only call*, jp* and jr* commands can contain label references"
        end

        # set addr arg to 0 for now, will be adjusted to label loc at end
        parts[1] = "0"
      end

      case nr_parts
      when 1
        res = instr_single(parts[0])
      when 2
        # is the second part an argument or part of a single instruction i.e. LD A,B
        if !include_dir_addr?(parts[0]) && ($regs.include?(parts[1]) || $regs.include?(between_parens(parts[1])))
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

  labels.keys.each do |key|
    throw "you must specify org if you want to use absolute reference labels" if abs_addrs.keys.length > 0 && org == -1

    if abs_addrs[key]
      abs_addrs[key].each do |x|
        # change the instr address arg to be the address the label points to
        code[x + 1], code [x + 2] = double_hex(org + labels[key])
      end
    end

    if rel_addrs[key]
      rel_addrs[key].each do |x|
        # Change the instr address arg to be the difference between the 
        # *next* instruction address and the address the label points to.
        # Assuming jump instruction is always 2 bytes.
        code[x + 1] = as_twos(labels[key] - (x + 2))
      end
    end
  end

  #puts code.map{|x| x.to_s(16).rjust(2, '0')}.join(" ")
  print code.pack("C*")
end

def as_twos(nr)
  throw "nr must be between -128 and 127" if nr < -128 || nr > 127
  return nr if nr > -1 
  256 + nr
end

def between_parens(str)
  op = str.index("(")
  cp = str.index(")")

  if op && cp
    str[op + 1, cp - op - 1]
  else
    nil
  end
end

# nr must be an int
def double_hex(nr)
  if nr < 256
    [ nr, 0 ]
  else
    [ nr % 256, nr / 256 ]
  end
end

def extract_label(str)
  str[1, str.length - 1].to_sym
end

def hex_or_int(str)
  if str.start_with?("0x") 
    str[2, str.length - 1].to_i(16)
  elsif str.end_with?("h")
    str[0, str.length - 1].to_i(16)
  elsif str.index(/[abcdef]/) || (str.length % 2 == 0 && str.start_with?("0"))
    str.to_i(16)
  else
    str.to_i
  end
end

def include_addr?(str)
  str.index("(") && str.index(")")
end

# only true if direct address (nr, not via reg)
def include_dir_addr?(str)
  include_addr?(str) && !$regs.include?(between_parens(str))
end

def include_label_ref?(str)
  str.index(":")
end

def instr_double(instr, arg)
  instr_op = instr.index("(") # checking for address in instruction
  instr_cp = instr.index(")")

  if instr_op && instr_cp # address in instruction
    if instr.start_with?("ld")
      # extract the address
      nr = hex_or_int(instr[instr_op + 1, instr_cp - instr_op - 1])
      case arg
      when "a"
        res = [ 0x3a ]
        res += double_hex(nr)
      when "bc"
        res = [ 0xed, 0x43 ]
        res += double_hex(nr)
      when "de"
        res = [ 0xed, 0x53 ]
        res += double_hex(nr)
      when "hl"
        res = [ 0x22 ]
        res += double_hex(nr)
      when "sp"
        res = [ 0xed, 0x73 ]
        res += double_hex(nr)
      end
    end
  elsif arg.start_with?("(") && arg.end_with?(")") # address in arg
    nr = hex_or_int(arg[1, arg.length - 2])
    case instr
    when "ld a" : [ 0x3a, double_hex(nr) ]
    when "ld bc"
      res = [ 0xed, 0x4b ]
      res += double_hex(nr)
    when "ld de"
      res = [ 0xed, 0x5b ]
      res += double_hex(nr)
    when "ld hl"
      res = [ 0x2a ]
      res += double_hex(nr)
    when "ld sp"
      res = [ 0xed, 0x7b ]
      res += double_hex(nr)
    end
  else # no addressing
    nr = hex_or_int(arg)
    case instr
    when "add a" : [ 0xc6, single_hex(nr) ]
    when "adc a" : [ 0xce, single_hex(nr) ]
    when "call"
      res = [ 0xcd ]
      res += double_hex(nr)
    when "call nz"
      res = [ 0xc4 ]
      res += double_hex(nr)
    when "call z"
      res = [ 0xcc ]
      res += double_hex(nr)
    when "call nc"
      res = [ 0xd4 ]
      res += double_hex(nr)
    when "call c"
      res = [ 0xdc ]
      res += double_hex(nr)
    when "call po"
      res = [ 0xe4 ]
      res += double_hex(nr)
    when "call pe"
      res = [ 0xec ]
      res += double_hex(nr)
    when "call p"
      res = [ 0xf4 ]
      res += double_hex(nr)
    when "call m"
      res = [ 0xfc ]
      res += double_hex(nr)
    when "cp" : [ 0xfe, single_hex(nr) ]
    when "jp"
      res = [ 0xc3 ]
      res += double_hex(nr)
    when "jp nz"
      res = [ 0xc2 ]
      res += double_hex(nr)
    when "jp z"
      res = [ 0xca ]
      res += double_hex(nr)
    when "jp nc"
      res = [ 0xd2 ]
      res += double_hex(nr)
    when "jp c"
      res = [ 0xda ]
      res += double_hex(nr)
    when "jp po"
      res = [ 0xe2 ]
      res += double_hex(nr)
    when "jp pe"
      res = [ 0xea ]
      res += double_hex(nr)
    when "jp p"
      res = [ 0xf2 ]
      res += double_hex(nr)
    when "jp m"
      res = [ 0xfa ]
      res += double_hex(nr)
    when "jr" : [ 0x18, single_hex(nr) ]
    when "jr nz" : [ 0x20, single_hex(nr) ]
    when "jr z" : [ 0x28, single_hex(nr) ]
    when "jr nc" : [ 0x30, single_hex(nr) ]
    when "jr c" : [ 0x38, single_hex(nr) ]
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
    when "ld sp"
      res = [ 0x31 ]
      res += double_hex(nr)
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
    when "adc hl,sp" : [ 0xed, 0x7a ]
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
    when "add hl,sp" : 0x39
    when "ccf" : 0x3f
    when "cp a" : 0xbf
    when "cp b" : 0xb8
    when "cp c" : 0xb9
    when "cp d" : 0xba
    when "cp e" : 0xbb
    when "cp h" : 0xbc
    when "cp l" : 0xbd
    when "cp (hl)" : 0xbe
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
    when "dec sp" : 0x3b
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
    when "inc sp" : 0x33
    when "ld (bc),a" : 0x02
    when "ld (de),a" : 0x12
    when "ld (hl),a" : 0x77
    when "ld (hl),b" : 0x70
    when "ld (hl),c" : 0x71
    when "ld (hl),d" : 0x72
    when "ld (hl),e" : 0x73
    when "ld (hl),h" : 0x74
    when "ld (hl),l" : 0x75
    when "ld a,(bc)" : 0x0a
    when "ld a,(de)" : 0x1a
    when "ld a,(hl)" : 0x7e
    when "ld a,a" : 0x7f
    when "ld a,b" : 0x78
    when "ld a,c" : 0x79
    when "ld a,d" : 0x7a
    when "ld a,e" : 0x7b
    when "ld a,h" : 0x7c
    when "ld a,l" : 0x7d
    when "ld b,(hl)" : 0x46
    when "ld b,a" : 0x47
    when "ld b,b" : 0x40
    when "ld b,c" : 0x41
    when "ld b,d" : 0x42
    when "ld b,e" : 0x43
    when "ld b,h" : 0x44
    when "ld b,l" : 0x45
    when "ld c,(hl)" : 0x4e
    when "ld c,a" : 0x4f
    when "ld c,b" : 0x48
    when "ld c,c" : 0x49
    when "ld c,d" : 0x4a
    when "ld c,e" : 0x4b
    when "ld c,h" : 0x4c
    when "ld c,l" : 0x4d
    when "ld d,(hl)" : 0x56
    when "ld d,a" : 0x57
    when "ld d,b" : 0x50
    when "ld d,c" : 0x51
    when "ld d,d" : 0x52
    when "ld d,e" : 0x53
    when "ld d,h" : 0x54
    when "ld d,l" : 0x55
    when "ld e,(hl)" : 0x5e
    when "ld e,a" : 0x5f
    when "ld e,b" : 0x58
    when "ld e,c" : 0x59
    when "ld e,d" : 0x5a
    when "ld e,e" : 0x5b
    when "ld e,h" : 0x5c
    when "ld e,l" : 0x5d
    when "ld h,(hl)" : 0x66
    when "ld h,a" : 0x67
    when "ld h,b" : 0x60
    when "ld h,c" : 0x61
    when "ld h,d" : 0x62
    when "ld h,e" : 0x63
    when "ld h,h" : 0x64
    when "ld h,l" : 0x65
    when "ld l,(hl)" : 0x6e
    when "ld l,a" : 0x6f
    when "ld l,b" : 0x68
    when "ld l,c" : 0x69
    when "ld l,d" : 0x6a
    when "ld l,e" : 0x6b
    when "ld l,h" : 0x6d
    when "ld l,l" : 0x6e
    when "ld sp,hl" : 0xf9
    when "ldi" : [ 0xed, 0xa0 ]
    when "ldir" : [ 0xed, 0xb0 ]
    when "ldd" : [ 0xed, 0xa8 ]
    when "lddr" : [ 0xed, 0xb8 ]
    when "ret" : 0xc9
    when "ret nz" : 0xc0
    when "ret z" : 0xc8
    when "ret nc" : 0xd0
    when "ret c" : 0xd8
    when "ret po" : 0xe0
    when "ret pe" : 0xe8
    when "ret p" : 0xf0
    when "ret m" : 0xf8
    when "pop af" : 0xf1
    when "pop bc" : 0xc1
    when "pop de" : 0xd1
    when "pop hl" : 0xe1
    when "push af" : 0xf5
    when "push bc" : 0xc5
    when "push de" : 0xd5
    when "push hl" : 0xe5
    when "sbc a,a" : 0x9f
    when "sbc a,b" : 0x98
    when "sbc a,c" : 0x99
    when "sbc a,c" : 0x9a
    when "sbc a,e" : 0x9b
    when "sbc a,h" : 0x9c
    when "sbc hl,bc" : [ 0xed, 0x42 ]
    when "sbc hl,de" : [ 0xed, 0x52 ]
    when "sbc hl,hl" : [ 0xed, 0x62 ]
    when "sbc hl,sp" : [ 0xed, 0x72 ]
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


