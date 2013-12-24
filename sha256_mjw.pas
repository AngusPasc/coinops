{$mode delphi}{$asmmode intel}
program sha256_mjw;
uses sysutils, dateutils;

type
  T256BitDigest = array[0..7] of uint32;
  T512BitBuf = array[0..63] of Byte;


procedure DigestToHexBufA(const Digest; const Size: Integer; const Buf); inline;
  const
    s_HexDigitsLower : array[0..15] of char = '0123456789abcdef';

  var I : Integer;
    P : PAnsiChar;
    Q : PByte;
  begin
    P := @Buf;
    Q := @Digest;
    for I := 0 to Size - 1 do
      begin
	P^ := s_HexDigitsLower[Q^ shr 4];
	Inc(P);
	P^ := s_HexDigitsLower[Q^ and 15];
	Inc(P);
	Inc(Q);
      end;
  end;

function DigestToHexA(const Digest; const Size: Integer): AnsiString; inline;
  begin
    SetLength(Result, Size * 2);
    DigestToHexBufA(Digest, Size, Pointer(Result)^);
  end;

procedure SwapEndianBuf(var Buf; const Count: Integer); inline;
  var P : PLongWord; I : Integer;
  begin
    P := @Buf;
    for I := 1 to Count do
    begin
      P^ := SwapEndian(P^);
      Inc(P);
    end;
  end;

procedure SHA256InitDigest(var Digest: T256BitDigest); inline;
  begin
    Digest[0] := $6a09e667;
    Digest[1] := $bb67ae85;
    Digest[2] := $3c6ef372;
    Digest[3] := $a54ff53a;
    Digest[4] := $510e527f;
    Digest[5] := $9b05688c;
    Digest[6] := $1f83d9ab;
    Digest[7] := $5be0cd19;
  end;


const
  // first 32 bits of the fractional parts of the cube roots of the first 64 primes 2..311
  SHA256K: array[0..63] of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5,
    $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3,
    $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc,
    $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7,
    $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13,
    $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3,
    $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5,
    $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208,
    $90befffa, $a4506ceb, $bef9a3f7, $c67178f2
  );

procedure TransformSHA256Buffer(var Digest: T256BitDigest; const Buf); inline;
var
  I : Integer;
  W : array[0..63] of uint32;
  P : ^uint32;
  S0, S1, Maj, T1, T2 : uint32;
  a,b,c,d,e,f,g,h : uint32;

begin
  P := @Buf;

  { 0.002s }
  for I := 0 to 15 do
    begin
      W[I] := SwapEndian(P^);
      Inc(P);
    end;

  for I := 16 to 63 do
    begin
      s0 := w[i-15];
      asm
        MOV r8d, s0
        ROR r8d, 7
        MOV r9d, r8d
        ROR r8d, 11    // for a total of 18
        XOR r9d, r8d
        MOV r8d, s0
        SHR r8d, 3
        XOR r9d, r8d
        MOV s0,  r9d
      end ['r8','r9'];
      S1 := w[i-2];
      asm
        MOV r8d, s1
        ROR r8d, 17
        MOV r9d, r8d
        ROR r8d, 2    // for a total of 19
        XOR r9d, r8d
        MOV r8d, s1
        SHR r8d, 10
        XOR r9d, r8d
        MOV s1,  r9d
      end ['r8','r9'];
      W[I] := W[I - 16] + S0 + W[I - 7] + S1;
    end;

  {a := digest[0]; b := digest[1];}
  c := digest[2]; d := digest[3];
  e := digest[4]; f := digest[5];
  g := digest[6]; h := digest[7];
  asm
    MOV  r13d, $6a09e667;  MOVD  mm0, r13d
    MOV  r13d, $bb67ae85;  MOVD  mm1, r13d
    //MOV  r13d, c  ;  MOVD  mm2, r13d
    //MOV  r13d, d  ;  MOVD  mm3, r13d
    //MOV  r13d, e  ;  MOVD  mm4, r13d
    //MOV  r13d, f  ;  MOVD  mm5, r13d
    //MOV  r13d, g  ;  MOVD  mm6, r13d
    //MOV  r13d, h  ;  MOVD  mm7, r13d
  end;

  asm
    mov ecx, 0
    @start: { for ecx := 0 to 63 }

      // s0 {r10d} := ror(a, 2) xor ror(a, 13) xor ror(a, 22)
      // s1 {r11d} := ror(e, 6) xor ror(e, 11) xor ror(e, 25)
        MOVD r8d, mm0              ; MOV r9d, e
        ROR r8d, 2		   ; ROR r9d, 6
        MOV r10d, r8d		   ; MOV r11d, r9d
        ROR r8d, 11    {13 total}  ; ROR r9d, 5     {11 total}
        XOR r10d, r8d		   ; XOR r11d, r9d
        ROR r8d, 9     {22 total}  ; ROR r9d, 14    {25 total}
        XOR r10d, r8d		   ; XOR r11d, r9d

        // maj { r12d } := (a and b) xor (a and c) xor (b and c)
        movd r8d,  mm0
        movd r9d,  mm1
        mov r13d, r9d // set aside a copy of b
        and r9d,  r8d
        mov r12d, c

        and r8d, r12d  { a and c }
        xor r9d, r8d
        and r12d, r13d { c and b }
        xor r12d, r9d

        // T2 {r12d} := S0 {r10d} + Maj {r12d};
        ADD r12d, r10d

        // Ch {r8d} := (e and f) xor ((not e) and g);
        mov r8d, f
        mov r9d, e
        and r8d, r9d
        not r9d
        mov r10d, g
        and r9d, r10d
        xor r8d, r9d

        // T1 {r11d} := H[7] + S1{r11d} + Ch_ + SHA256K[I] + W[I];
        ADD r11d, h
        ADD r11d, r8d { ch }
        ADD r11d, SHA256K[rcx*4]
        ADD r11d, W[rcx*4]

        MOV   r8d, g     ; MOV    h, r8d  { h := g }
        MOV   r8d, f     ; MOV    g, r8d  { g := f }
        MOV   r8d, e     ; MOV    f, r8d  { f := e }
        MOV   r8d, d
        ADD   r8d, r11d  ; MOV    e, r8d  { e := d + t1 }
        MOV   r8d, c     ; MOV    d, r8d  { d := c }
        MOVD  r8d, mm1   ; MOV    c, r8d  { c := b }
        MOVD  r8d, mm0   ; MOVD mm1, r8d  { b := a }
        ADD  r11d, r12d  ; MOVD mm0, r11d { a := t1 + t2 }

      inc ecx
      cmp ecx, 64
      jne @start
    end;

  { 0.003 }
  asm
    MOVD r13d, mm0  ;   MOV  a, r13d
    MOVD r13d, mm1  ;   MOV  b, r13d
    // MOVD r13d, mm2  ;   MOV  c, r13d
    // MOVD r13d, mm3  ;   MOV  d, r13d
    // MOVD r13d, mm4  ;   MOV  e, r13d
    // MOVD r13d, mm5  ;   MOV  f, r13d
    // MOVD r13d, mm6  ;   MOV  g, r13d
    // MOVD r13d, mm7  ;   MOV  h, r13d
    EMMS // clear mmx state
  end;
  inc(digest[0], a); inc(digest[1], b);
  inc(digest[2], c); inc(digest[3], d);
  inc(digest[4], e); inc(digest[5], f);
  inc(digest[6], g); inc(digest[7], h);

end;

{ Utility function to reverse order of data in buffer. }
procedure ReverseMem(var Buf; const BufSize: Integer); inline;
var I : Integer;
    P : PByte;
    Q : PByte;
    T : Byte;
begin
  P := @Buf;
  Q := P;
  Inc(Q, BufSize - 1);
  for I := 1 to BufSize div 2 do
    begin
      T := P^;
      P^ := Q^;
      Q^ := T;
      Inc(P);
      Dec(Q);
    end;
end;

{ Utility function to prepare final buffer(s).                         }
{ Fills Buf1 from Buf }
procedure StdFinalBuf512(const Buf; const BufSize : Integer;
			 var Buf1: T512BitBuf); inline;
  var Q : PByte; I : Integer; L : Int64;
  begin
    Q := @Buf1[0];
    Move(buf, buf1, BufSize);
    Inc(Q, BufSize);
    Q^ := $80;
    Inc(Q);
    L := BufSize * 8;
    ReverseMem(L, 8);
    I := 64 - Sizeof(Int64) - BufSize - 1;
    FillChar(Q^, I, #0);
    Inc(Q, I);
    PInt64(Q)^ := L;
  end;

function CalcSHA256(const Buf; const BufSize: Integer): T256BitDigest;
  overload; inline;
  var B1 : T512BitBuf;
  begin
    SHA256InitDigest(Result);
    StdFinalBuf512(Buf, BufSize, B1);
    TransformSHA256Buffer(Result, B1);
    SwapEndianBuf(Result, Sizeof(Result) div Sizeof(LongWord));
  end;

function CalcSHA256(const Buf: AnsiString): T256BitDigest; overload; inline;
  begin
    Result := CalcSHA256(Pointer(Buf)^, Length(Buf));
  end;

function SHA256DigestToHexA(const Digest: T256BitDigest): AnsiString; inline;
  begin
    Result := DigestToHexA(Digest, Sizeof(Digest));
  end;


var i : integer; t : TDateTime; d : T256BitDigest;
const
  s = '0123456789ABCDEF0123456789ABCDEF';
  n = 65536;

begin
  t := now;
  d := CalcSHA256(s);
  for i := 2 to n do d := CalcSHA256(d, 32);
  writeln('recursively applied SHA256 to "', s, '" ', n, ' times in ',
	  Format('%0.3n',[MilliSecondsBetween( now, t )/1000]) : 3, 's.');
  writeln(SHA256DigestToHexA(d));
end.

{******************************************************************************}
{                                                                              }
{   Library:          Fundamentals 4.00                                        }
{   File name:        cHash.pas                                                }
{   File version:     4.18                                                     }
{   Description:      Hashing functions                                        }
{                                                                              }
{   Copyright:        Copyright (c) 1999-2013, David J Butler                  }
{                     All rights reserved.                                     }
{                     Redistribution and use in source and binary forms, with  }
{                     or without modification, are permitted provided that     }
{                     the following conditions are met:                        }
{                     Redistributions of source code must retain the above     }
{                     copyright notice, this list of conditions and the        }
{                     following disclaimer.                                    }
{                     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND   }
{                     CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED          }
{                     WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED   }
{                     WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A          }
{                     PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL     }
{                     THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,    }
{                     INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR             }
{                     CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,    }
{                     PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF     }
{                     USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)         }
{                     HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER   }
{                     IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING        }
{                     NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE   }
{                     USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE             }
{                     POSSIBILITY OF SUCH DAMAGE.                              }
{                                                                              }
{   Home page:        http://fundementals.sourceforge.net                      }
{   Forum:            http://sourceforge.net/forum/forum.php?forum_id=2117     }
{   E-mail:           fundamentals.library@gmail.com                           }
