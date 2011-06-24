$regs = ["a", "af", "b", "bc", "c", "d", "de", "e", "h", "hl", "l", "sp"]
$sfxs = ["nz", "z", "nc", "c", "po", "pe", "p", "m"]

def as_twos(nr)
  throw "nr must be between -128 and 127" if nr < -128 || nr > 127
  return nr if nr > -1 
  256 + nr
end

def between(str, a, b)
  op = str.index(a)
  if op
    cp = str.index(b, op + 1)

    if cp
      str[op + 1, cp - op - 1]
    else
      nil
    end
  end
end

def between_parens(str)
  between(str, "(", ")")
end

def between_quotes(str)
  between(str, '"', '"')
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
  if str.start_with?('"') 
    between_quotes(str).bytes.to_a[0] # only look at first char
  elsif str.start_with?("0x") 
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
        res = [ 0x32 ]
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
    when "defb"
      res = single_hex(nr)
    when "defm"
      res = arg.bytes.to_a
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
    when "and a" : 0xa7
    when "and b" : 0xa0
    when "and c" : 0xa1
    when "and d" : 0xa2
    when "and e" : 0xa3
    when "and h" : 0xa4
    when "and l" : 0xa5
    when "and (hl)" : 0xa6
    when "bit 0,a" : [ 0xcb, 0x47 ]
    when "bit 0,b" : [ 0xcb, 0x40 ]
    when "bit 0,c" : [ 0xcb, 0x41 ]
    when "bit 0,d" : [ 0xcb, 0x42 ]
    when "bit 0,e" : [ 0xcb, 0x43 ]
    when "bit 0,h" : [ 0xcb, 0x44 ]
    when "bit 0,l" : [ 0xcb, 0x45 ]
    when "bit 0,(hl)" : [ 0xcb, 0x46 ]
    when "bit 1,a" : [ 0xcb, 0x4f ]
    when "bit 1,b" : [ 0xcb, 0x48 ]
    when "bit 1,c" : [ 0xcb, 0x49 ]
    when "bit 1,d" : [ 0xcb, 0x4a ]
    when "bit 1,e" : [ 0xcb, 0x4b ]
    when "bit 1,h" : [ 0xcb, 0x4c ]
    when "bit 1,l" : [ 0xcb, 0x4d ]
    when "bit 1,(hl)" : [ 0xcb, 0x4e ]
    when "bit 2,a" : [ 0xcb, 0x57 ]
    when "bit 2,b" : [ 0xcb, 0x50 ]
    when "bit 2,c" : [ 0xcb, 0x51 ]
    when "bit 2,d" : [ 0xcb, 0x52 ]
    when "bit 2,e" : [ 0xcb, 0x53 ]
    when "bit 2,h" : [ 0xcb, 0x54 ]
    when "bit 2,l" : [ 0xcb, 0x55 ]
    when "bit 2,(hl)" : [ 0xcb, 0x56 ]
    when "bit 3,a" : [ 0xcb, 0x5f ]
    when "bit 3,b" : [ 0xcb, 0x58 ]
    when "bit 3,c" : [ 0xcb, 0x59 ]
    when "bit 3,d" : [ 0xcb, 0x5a ]
    when "bit 3,e" : [ 0xcb, 0x5b ]
    when "bit 3,h" : [ 0xcb, 0x5c ]
    when "bit 3,l" : [ 0xcb, 0x5d ]
    when "bit 3,(hl)" : [ 0xcb, 0x5e ]
    when "bit 4,a" : [ 0xcb, 0x67 ]
    when "bit 4,b" : [ 0xcb, 0x60 ]
    when "bit 4,c" : [ 0xcb, 0x61 ]
    when "bit 4,d" : [ 0xcb, 0x62 ]
    when "bit 4,e" : [ 0xcb, 0x63 ]
    when "bit 4,h" : [ 0xcb, 0x64 ]
    when "bit 4,l" : [ 0xcb, 0x65 ]
    when "bit 4,(hl)" : [ 0xcb, 0x66 ]
    when "bit 5,a" : [ 0xcb, 0x6f ]
    when "bit 5,b" : [ 0xcb, 0x68 ]
    when "bit 5,c" : [ 0xcb, 0x69 ]
    when "bit 5,d" : [ 0xcb, 0x6a ]
    when "bit 5,e" : [ 0xcb, 0x6b ]
    when "bit 5,h" : [ 0xcb, 0x6c ]
    when "bit 5,l" : [ 0xcb, 0x6d ]
    when "bit 5,(hl)" : [ 0xcb, 0x6e ]
    when "bit 6,a" : [ 0xcb, 0x77 ]
    when "bit 6,b" : [ 0xcb, 0x70 ]
    when "bit 6,c" : [ 0xcb, 0x71 ]
    when "bit 6,d" : [ 0xcb, 0x72 ]
    when "bit 6,e" : [ 0xcb, 0x73 ]
    when "bit 6,h" : [ 0xcb, 0x74 ]
    when "bit 6,l" : [ 0xcb, 0x75 ]
    when "bit 6,(hl)" : [ 0xcb, 0x76 ]
    when "bit 7,a" : [ 0xcb, 0x7f ]
    when "bit 7,b" : [ 0xcb, 0x78 ]
    when "bit 7,c" : [ 0xcb, 0x79 ]
    when "bit 7,d" : [ 0xcb, 0x7a ]
    when "bit 7,e" : [ 0xcb, 0x7b ]
    when "bit 7,h" : [ 0xcb, 0x7c ]
    when "bit 7,l" : [ 0xcb, 0x7d ]
    when "bit 7,(hl)" : [ 0xcb, 0x7e ]
    when "ccf" : 0x3f
    when "cp a" : 0xbf
    when "cp b" : 0xb8
    when "cp c" : 0xb9
    when "cp d" : 0xba
    when "cp e" : 0xbb
    when "cp h" : 0xbc
    when "cp l" : 0xbd
    when "cp (hl)" : 0xbe
    when "cpl" : 0x2f
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
    when "or a" : 0xb7
    when "or b" : 0xb0
    when "or c" : 0xb1
    when "or d" : 0xb2
    when "or e" : 0xb3
    when "or h" : 0xb4
    when "or l" : 0xb5
    when "or (hl)" : 0xb6
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
    when "res 0,a" : [ 0xcb, 0x87 ]
    when "res 0,b" : [ 0xcb, 0x80 ]
    when "res 0,c" : [ 0xcb, 0x81 ]
    when "res 0,d" : [ 0xcb, 0x82 ]
    when "res 0,e" : [ 0xcb, 0x83 ]
    when "res 0,h" : [ 0xcb, 0x84 ]
    when "res 0,l" : [ 0xcb, 0x85 ]
    when "res 0,(hl)" : [ 0xcb, 0x86 ]
    when "res 1,a" : [ 0xcb, 0x8f ]
    when "res 1,b" : [ 0xcb, 0x88 ]
    when "res 1,c" : [ 0xcb, 0x89 ]
    when "res 1,d" : [ 0xcb, 0x8a ]
    when "res 1,e" : [ 0xcb, 0x8b ]
    when "res 1,h" : [ 0xcb, 0x8c ]
    when "res 1,l" : [ 0xcb, 0x8d ]
    when "res 1,(hl)" : [ 0xcb, 0x8e ]
    when "res 2,a" : [ 0xcb, 0x97 ]
    when "res 2,b" : [ 0xcb, 0x90 ]
    when "res 2,c" : [ 0xcb, 0x91 ]
    when "res 2,d" : [ 0xcb, 0x92 ]
    when "res 2,e" : [ 0xcb, 0x93 ]
    when "res 2,h" : [ 0xcb, 0x94 ]
    when "res 2,l" : [ 0xcb, 0x95 ]
    when "res 2,(hl)" : [ 0xcb, 0x96 ]
    when "res 3,a" : [ 0xcb, 0x9f ]
    when "res 3,b" : [ 0xcb, 0x98 ]
    when "res 3,c" : [ 0xcb, 0x99 ]
    when "res 3,d" : [ 0xcb, 0x9a ]
    when "res 3,e" : [ 0xcb, 0x9b ]
    when "res 3,h" : [ 0xcb, 0x9c ]
    when "res 3,l" : [ 0xcb, 0x9d ]
    when "res 3,(hl)" : [ 0xcb, 0x9e ]
    when "res 4,a" : [ 0xcb, 0xa7 ]
    when "res 4,b" : [ 0xcb, 0xa0 ]
    when "res 4,c" : [ 0xcb, 0xa1 ]
    when "res 4,d" : [ 0xcb, 0xa2 ]
    when "res 4,e" : [ 0xcb, 0xa3 ]
    when "res 4,h" : [ 0xcb, 0xa4 ]
    when "res 4,l" : [ 0xcb, 0xa5 ]
    when "res 4,(hl)" : [ 0xcb, 0xa6 ]
    when "res 5,a" : [ 0xcb, 0xaf ]
    when "res 5,b" : [ 0xcb, 0xa8 ]
    when "res 5,c" : [ 0xcb, 0xa9 ]
    when "res 5,d" : [ 0xcb, 0xaa ]
    when "res 5,e" : [ 0xcb, 0xab ]
    when "res 5,h" : [ 0xcb, 0xac ]
    when "res 5,l" : [ 0xcb, 0xad ]
    when "res 5,(hl)" : [ 0xcb, 0xae ]
    when "res 6,a" : [ 0xcb, 0xb7 ]
    when "res 6,b" : [ 0xcb, 0xb0 ]
    when "res 6,c" : [ 0xcb, 0xb1 ]
    when "res 6,d" : [ 0xcb, 0xb2 ]
    when "res 6,e" : [ 0xcb, 0xb3 ]
    when "res 6,h" : [ 0xcb, 0xb4 ]
    when "res 6,l" : [ 0xcb, 0xb5 ]
    when "res 6,(hl)" : [ 0xcb, 0xb6 ]
    when "res 7,a" : [ 0xcb, 0xbf ]
    when "res 7,b" : [ 0xcb, 0xb8 ]
    when "res 7,c" : [ 0xcb, 0xb9 ]
    when "res 7,d" : [ 0xcb, 0xba ]
    when "res 7,e" : [ 0xcb, 0xbb ]
    when "res 7,h" : [ 0xcb, 0xbc ]
    when "res 7,l" : [ 0xcb, 0xbd ]
    when "res 7,(hl)" : [ 0xcb, 0xbe ]
    when "rl a" : [ 0xcb, 0x17 ]
    when "rl b" : [ 0xcb, 0x10 ]
    when "rl c" : [ 0xcb, 0x11 ]
    when "rl d" : [ 0xcb, 0x12 ]
    when "rl e" : [ 0xcb, 0x13 ]
    when "rl h" : [ 0xcb, 0x14 ]
    when "rl l" : [ 0xcb, 0x15 ]
    when "rl (hl)" : [ 0xcb, 0x16 ]
    when "rlc a" : [ 0xcb, 0x07 ]
    when "rlc b" : [ 0xcb, 0x00 ]
    when "rlc c" : [ 0xcb, 0x01 ]
    when "rlc d" : [ 0xcb, 0x02 ]
    when "rlc e" : [ 0xcb, 0x03 ]
    when "rlc h" : [ 0xcb, 0x04 ]
    when "rlc l" : [ 0xcb, 0x05 ]
    when "rlc (hl)" : [ 0xcb, 0x06 ]
    when "rr a" : [ 0xcb, 0x1f ]
    when "rr b" : [ 0xcb, 0x18 ]
    when "rr c" : [ 0xcb, 0x19 ]
    when "rr d" : [ 0xcb, 0x1a ]
    when "rr e" : [ 0xcb, 0x1b ]
    when "rr h" : [ 0xcb, 0x1c ]
    when "rr l" : [ 0xcb, 0x1d ]
    when "rr (hl)" : [ 0xcb, 0x1e ]
    when "rrc a" : [ 0xcb, 0x0f ]
    when "rrc b" : [ 0xcb, 0x08 ]
    when "rrc c" : [ 0xcb, 0x09 ]
    when "rrc d" : [ 0xcb, 0x0a ]
    when "rrc e" : [ 0xcb, 0x0b ]
    when "rrc h" : [ 0xcb, 0x0c ]
    when "rrc l" : [ 0xcb, 0x0d ]
    when "rrc (hl)" : [ 0xcb, 0x0e ]
    when "rst 10" : 0xd7
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
    when "set 0,a" : [ 0xcb, 0xc7 ]
    when "set 0,b" : [ 0xcb, 0xc0 ]
    when "set 0,c" : [ 0xcb, 0xc1 ]
    when "set 0,d" : [ 0xcb, 0xc2 ]
    when "set 0,e" : [ 0xcb, 0xc3 ]
    when "set 0,h" : [ 0xcb, 0xc4 ]
    when "set 0,l" : [ 0xcb, 0xc5 ]
    when "set 0,(hl)" : [ 0xcb, 0xc6 ]
    when "set 1,a" : [ 0xcb, 0xcf ]
    when "set 1,b" : [ 0xcb, 0xc8 ]
    when "set 1,c" : [ 0xcb, 0xc9 ]
    when "set 1,d" : [ 0xcb, 0xca ]
    when "set 1,e" : [ 0xcb, 0xcb ]
    when "set 1,h" : [ 0xcb, 0xcc ]
    when "set 1,l" : [ 0xcb, 0xcd ]
    when "set 1,(hl)" : [ 0xcb, 0xce ]
    when "set 2,a" : [ 0xcb, 0xd7 ]
    when "set 2,b" : [ 0xcb, 0xd0 ]
    when "set 2,c" : [ 0xcb, 0xd1 ]
    when "set 2,d" : [ 0xcb, 0xd2 ]
    when "set 2,e" : [ 0xcb, 0xd3 ]
    when "set 2,h" : [ 0xcb, 0xd4 ]
    when "set 2,l" : [ 0xcb, 0xd5 ]
    when "set 2,(hl)" : [ 0xcb, 0xd6 ]
    when "set 3,a" : [ 0xcb, 0xdf ]
    when "set 3,b" : [ 0xcb, 0xd8 ]
    when "set 3,c" : [ 0xcb, 0xd9 ]
    when "set 3,d" : [ 0xcb, 0xda ]
    when "set 3,e" : [ 0xcb, 0xdb ]
    when "set 3,h" : [ 0xcb, 0xdc ]
    when "set 3,l" : [ 0xcb, 0xdd ]
    when "set 3,(hl)" : [ 0xcb, 0xde ]
    when "set 4,a" : [ 0xcb, 0xe7 ]
    when "set 4,b" : [ 0xcb, 0xe0 ]
    when "set 4,c" : [ 0xcb, 0xe1 ]
    when "set 4,d" : [ 0xcb, 0xe2 ]
    when "set 4,e" : [ 0xcb, 0xe3 ]
    when "set 4,h" : [ 0xcb, 0xe4 ]
    when "set 4,l" : [ 0xcb, 0xe5 ]
    when "set 4,(hl)" : [ 0xcb, 0xe6 ]
    when "set 5,a" : [ 0xcb, 0xef ]
    when "set 5,b" : [ 0xcb, 0xe8 ]
    when "set 5,c" : [ 0xcb, 0xe9 ]
    when "set 5,d" : [ 0xcb, 0xea ]
    when "set 5,e" : [ 0xcb, 0xeb ]
    when "set 5,h" : [ 0xcb, 0xec ]
    when "set 5,l" : [ 0xcb, 0xed ]
    when "set 5,(hl)" : [ 0xcb, 0xee ]
    when "set 6,a" : [ 0xcb, 0xf7 ]
    when "set 6,b" : [ 0xcb, 0xf0 ]
    when "set 6,c" : [ 0xcb, 0xf1 ]
    when "set 6,d" : [ 0xcb, 0xf2 ]
    when "set 6,e" : [ 0xcb, 0xf3 ]
    when "set 6,h" : [ 0xcb, 0xf4 ]
    when "set 6,l" : [ 0xcb, 0xf5 ]
    when "set 6,(hl)" : [ 0xcb, 0xf6 ]
    when "set 7,a" : [ 0xcb, 0xff ]
    when "set 7,b" : [ 0xcb, 0xf8 ]
    when "set 7,c" : [ 0xcb, 0xf9 ]
    when "set 7,d" : [ 0xcb, 0xfa ]
    when "set 7,e" : [ 0xcb, 0xfb ]
    when "set 7,h" : [ 0xcb, 0xfc ]
    when "set 7,l" : [ 0xcb, 0xfd ]
    when "set 7,(hl)" : [ 0xcb, 0xfe ]
    when "sub a" : 0x97
    when "sub b" : 0x90
    when "sub c" : 0x91
    when "sub d" : 0x92
    when "sub e" : 0x93
    when "sub h" : 0x94
    when "sub l" : 0x95
    when "xor a" : 0xaf
    when "xor b" : 0xa8
    when "xor c" : 0xa9
    when "xor d" : 0xaa
    when "xor e" : 0xab
    when "xor h" : 0xac
    when "xor l" : 0xad
    when "xor (hl)" : 0xae
  else
    throw "Unrecognised instruction #{instr}"
  end
end

# puts string into lower case ignoring defm and letters in quotes 
# presumes a single set of quotes per line
def lower_case(str)
  len = str.length

  if str.start_with?("defm")
    return str[0, 4].downcase + str[4, len - 1] 
  end

  a = str.index('"')

  if a
    b = str.index('"', a + 1)
    throw "unclosed string quote" if b.nil?
    
    c = str.index('"', b + 1)
    throw "can only have 1 quoted string per instruction" unless c.nil?
    
    str[0, a].downcase + str[a, b - a + 1] + str[b + 1, len - b - 1].downcase
  else
    str.downcase
  end
end

def main
  # test we have a filename
  puts "What file should I compile? Usage z80asm file_name" if ARGV.length == 0

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

      cmd = lower_case(cmd)

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

      # parse instruction
      parts = cmd.split(",").map(&:strip)
      nr_parts = parts.length
      res = nil

      # check for 'single' cmds with a numeric arg i.e. cp 32h
      # ignore anything with any addressing in first part of cmd
      if parts[0][0, 3] != "rst"
        if !include_addr?(parts[0]) || parts[0][0, 3] == "def" || parts[0][0, 4] == "jp :" || parts[0][0, 4] == "jr :"
          sub_parts = nil
          
          if parts[0][0, 3] == "def"
            sub_parts = split_once(parts[0], " ")
          else
            sub_parts = parts[0].split(" ").map(&:strip)
          end

          if sub_parts.length > 1
            # check if not reg or cmd suffix
            if !$regs.include?(sub_parts[1]) && !$sfxs.include?(sub_parts[1])
              parts[0] = sub_parts[0]
              parts[1] = sub_parts[0] == "defm" ? sub_parts[1..sub_parts.length - 1].join(" ") : sub_parts[1]
              nr_parts = 2
            end
          end
        end
      end

      # check for label references
      if include_label_ref?(parts[0])
        throw "only command args can contain label references '#{parts[0]}'"
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
  
  if ARGV[1]
    puts code.map{|x| x.to_s(16).rjust(2, '0')}.join(" ")
  else
    print code.pack("C*")
  end
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

def split_once(str, c)
  idx = str.index(c)

  [ str[0, idx], str[idx + 1, str.length - 1] ]
end
