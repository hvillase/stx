# STX v4 March 2022

# Lexer [or tokenizer] definition with language lexemes [or tokens]

@{%
  const lexer = moo.compile({
		comment: /--[^\n]*/,
		dac: /=>/,
		mixer: /<>/,
		sum: /\+/,
		mul: /\*/,
		pha: /\|/,
		parLeft: /\[/,
		parRight: /\]/,
		nameSample: /[a-zA-Z][a-zA-Z0-9]*/,
		number: /-?(?:[0-9]|[1-9][0-9]+)(?:\.[0-9]+)?\b/,
		loop: /~/,
		trig: /:/,
		separator: /,/,
		nameFunc: /[a-zA-Z][a-zA-Z0-9]*/,
		semicolon: /;/,
		ws: { match: /\s+/, lineBreaks: true }
  });
%}

# Pass your lexer object using the @lexer option
@lexer lexer

# Grammar definition in the Extended Backus Naur Form (EBNF)
main -> _ Statement _
{%
  function(d){ return { '@lang': d[1] } }
%}

Statement -> %comment _ Statement
{% d => d[2] %}
|
Expression _ %semicolon _ Statement
{% d => [ { '@spawn': d[0] } ].concat(d[4]) %}
|
Expression _ %semicolon (_ %comment):*
{% d => [ { '@spawn': d[0] } ] %}

Expression -> %nameSample __ %loop __ %number
{%
// Loop - name ~ num
  function(d){
		let number = sema.num(d[4].value);
		let name = sema.str(d[0].value);
		let sample = sema.synth('loop', [number, name]);
		return sample;
  }
%}
|
%nameSample __ %trig __ Expression
{%
// SampleTrig - name : [num num]
  function(d){
		let name = sema.str(d[0].value);
		let sample = sema.synth('sampler', [[d[4]], name]);
		return sample;
  }
%}
|
%nameSample __ %trig __ %number
{%
// SampleTrig No Impulse - name : num
  function(d){
		let name = sema.str(d[0].value);
		let number = sema.num(d[4].value);
		let sample = sema.synth('sampler', [number, name]);
		return sample;
  }
%}
|
%parLeft _ %number __ %number _ %parRight
{%
// Impulse - [num num]
  function(d){
	let fi = sema.num(d[2].value);
	let ph = sema.num(d[4].value);
	let imp = sema.synth('imp', [fi, ph]);
	return imp;
  }
%}
|
%number __ Expression
{%
// Sah receives SampleTrig or SampleTrig No Impulse rules
function(d){
	let time = sema.num(d[0].value);
	let sah = sema.synth('sah', [[d[2]], time]);
	return sah;
}
%}
|
%nameSample __ %number __ %number
{%
// Slice no impulse - num num name
function(d){
	let imps = sema.num(d[2].value);
	let offs = sema.num(d[4].value);
	let names = sema.str(d[0].value);
	let slice = sema.synth('slice', [imps, offs, names]);
	return slice;
}
%}
|
%nameSample __ Expression __ %number
{%
// Slice w/impulse - [num num] num name
function(d){
	let offs = sema.num(d[4].value);
	let names = sema.str(d[0].value);
	let slice = sema.synth('slice', [[d[2]], offs, names]);
	return slice;
}
%}
|
%nameSample __ Expression __ Expression
{%
// Slice w/impulse - [num num] pha[num num]
function(d){
	let names = sema.str(d[0].value);
	let slice = sema.synth('slice', [[d[2]], [d[4]], names]);
	return slice;
}
%}
|
%mul _ %number __ Expression
{%
// mul - *1 expression
function(d){
let num = sema.num(d[2].value);
let mul = sema.synth('mul', [d[4], num]);
return mul;
}
%}
|
%mixer __ FuncList
{% d => sema.synth('mix', d[2]) %}
|
%sum __ FuncList
{% d => sema.synth ('sum', d[2])%}
|
%pha __ %parLeft _ %number __ %number _ %parRight
{%
// phasor: freq, phase(0-1)
function(d){
let freq = sema.num(d[4].value);
let pha = sema.num(d[6].value);
let phasor = sema.synth('pha', [freq, pha]);
return phasor;
}
%}
|
%dac __ Expression
{% d => sema.synth('dac', [d[2]]) %}
|
%dac __ %parLeft _ %number _ %parRight __ Expression
{% function(d){
	let num = sema.num(d[4].value);
	let dacx = sema.synth('dac', [d[8], num]);
	return dacx;
	}
%}

FuncList -> Expression
{% d=> [d[0]] %}
|
Expression _ %separator _ FuncList
{% d => d[4].concat(d[0]) %}

# Whitespace
_  -> wschar:* {%  d => null%}
__ -> wschar:+ {% d=> null%}
wschar -> %ws {% id %}