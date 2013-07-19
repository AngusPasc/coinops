{$mode delphi}{$asmmode intel}
program sha256_mjw;
uses sysutils, dateutils;

type
  T256BitDigest = record
    case integer of
      0 : (Longs : array[0..7] of LongWord);
      1 : (Words : array[0..15] of Word);
      2 : (Bytes : array[0..31] of Byte);
    end;
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

function ror(const value: cardinal; const bits: Byte): cardinal; inline;
  begin
    result := value;
    asm
      MOV   CL, bits
      ROR   result, CL
    end
  end;

procedure SHA256InitDigest(var Digest: T256BitDigest); inline;
  begin
    Digest.Longs[0] := $6a09e667;
    Digest.Longs[1] := $bb67ae85;
    Digest.Longs[2] := $3c6ef372;
    Digest.Longs[3] := $a54ff53a;
    Digest.Longs[4] := $510e527f;
    Digest.Longs[5] := $9b05688c;
    Digest.Longs[6] := $1f83d9ab;
    Digest.Longs[7] := $5be0cd19;
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
  S0, S1, Maj, T1, T2, Ch_ : uint32;
  H : array[0..7] of uint32;
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

  { 0.004 }
  for I := 0 to 7 do H[I] := Digest.Longs[I];

  for I := 0 to 63 do
    begin

      // s0 := ror(h[0], 2) xor ror(h[0], 13) xor ror(h[0], 22)
      // s1 := ror(h[4], 6) xor ror(h[4], 11) xor ror(h[4], 25)
      asm
        MOV r8d, h[0]              ; MOV r9d, h[4*4]
        ROR r8d, 2		   ; ROR r9d, 6
        MOV r10d, r8d		   ; MOV r11d, r9d
        ROR r8d, 11    {13 total}  ; ROR r9d, 5     {11 total}
        XOR r10d, r8d		   ; XOR r11d, r9d
        ROR r8d, 9     {22 total}  ; ROR r9d, 14    {25 total}
        XOR r10d, r8d		   ; XOR r11d, r9d
                       		   ; MOV s1,  r11d
      end ['r8','r9', 'r10', 'r11'];

      { 0.012 }
      Maj := (H[0] and H[1]) xor (H[0] and H[2]) xor (H[1] and H[2]);
      // T2 := S0 + Maj;
      asm
        MOV r8d, maj
        // r10d still contains  s0, so now add them
        // we put the result in r8d so we can use s0 again later.
        ADD r8d, r10d
        MOV t2, r8d
      end;

      { 0.024 }
      Ch_ := (H[4] and H[5]) xor ((not H[4]) and H[6]);

      // T1 := H[7] + S1 + Ch_ + SHA256K[I] + W[I];
      asm
        MOV r13d, h[7*4]
        ADD r13d, r11d
        ADD r13d, Ch_
        MOV r8d, I
        SHL r8d, 2
        ADD r13d, SHA256K[r8]
        ADD r13d, W[r8]
        MOV T1, r13d
      end;

      { 0.027 }
      H[7] := H[6];
      H[6] := H[5];
      H[5] := H[4];
      H[4] := H[3] + T1;
      H[3] := H[2];
      H[2] := H[1];
      H[1] := H[0];
      H[0] := T1 + T2;
    end;

  { 0.003 }
  for I := 0 to 7 do Inc(Digest.Longs[I], H[I]);

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
