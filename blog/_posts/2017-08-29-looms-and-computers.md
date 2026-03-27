---
title: Looms and Computers
date: 2017-08-29
layout: post
abstract: The similarities between computers and looms, distant cousins related through their ancestor, the Jacquard loom.
thumbnail: warp-and-weft.png
author: Andrew McKnight
author-email: andrew@tworingsoft.com
tags: theory
---

The other day, my wife and I were talking about an arts and crafts project she was doing with her patients, adolescent girls in a therapeutic residential facility. For their summer project, they partnered with [Harrisville Designs](https://harrisville.com) to teach them the art of looming with the hope of supporting creativity, self-esteem, and social bonding. The more we talked about it, the more I started comparing looms to computers, as I am wont to do with, well, everything. Here are my findings from researching weaving and looms, together with what I know of how computers work. 

# Weaving

{% include 
	blog-post-image.html 
	source="warp-and-weft.png" 
	small=1
	alt="The _warp_ (lengthwise) and _weft_ (breadthwise) threads of a basic weave. (Image by http://commons.wikimedia.org/wiki/User:Ryj - http://commons.wikimedia.org/wiki/File:Kette_und_Schu%C3%9F.jpg, CC BY-SA 3.0, https://en.wikipedia.org/w/index.php?curid=37702470)" %}

A weave is a 2D construction where lengthwise (_warp_) threads intersect in various ways with breadthwise threads, thus all holding each other in place. The simplest weave is one where every warp thread alternates going under and over each pass of a single thread called the _weft_, where the starting positions also alternate between over/under. Because each warp thread can only be over or under, we could represent their positions with binary numbers: `1` for over and `0` for under. Thus, a simple weave of 6 warp threads could be described as such, where each row is a new pass of the weft, and each column is a warp thread:

	101010
	010101
	101010
	010101
	101010
	010101

Weaves need not proceed in a linear fashion. Doubling back, such as in a [Spanish lace](http://www.theweavingloom.com/weave-along-spanish-lace-weave/), hearkens to out-of-order processing in CPU architectures.

## Patterns

You can get more interesting patterns by varying the frequency of alternations, like twill:

	101110
	011101
	111011
	110111
	101110
	011101

Different weave patterns give the resulting cloth different properties like stretchiness, flexibility, tear resistence, smoothness, or decoration. To further decorate a cloth, different colors of threads may be used. Consider this plaid pattern:

{% include 
	blog-post-image.html 
	source="tartan.png" 
	small=1
	alt="A plaid pattern." %}
	
There are just a few color combinations used as you move down the warp. If you gave a number to each, you could describe a pattern or family of patterns like Scottish clan tartans with a higher-level description that outlines the colors and pattern sequences.

Trivia: from [interweave.com](https://www.interweave.com/article/weaving/whats-the-difference-between-tartan-and-plaid/) on plaid vs. tartan:

> Tartans have an identical pattern of stripes running vertically and horizontally, resulting in overlapping square grids. Regular plaids are not necessarily the same in both directions, with variation in color, size, and/or pattern of stripes. In addition, tartan is almost always woven in a two-over-two twill pattern, which forms the illusion of new colors blended from the original ones.

So there you have it, tartans actually make use of not just particular color pattern rules, but a weave pattern that achieves a visual effect!

## Looms

Several types of machines called [looms](https://en.wikipedia.org/wiki/Loom#Types_of_looms) have been devised to help assemble weaves. The Jacquard loom introduced a new dimension to the process by transcribing designs directly into representations that could automatically drive a machine to reproduce the images in weaves. An example of a predecessor to the modern day computer, it used punchcards in 1801 much like programmers in the early to mid 1900s used them in machines like ENIAC. Today, programs are written using textual languages not so different from spoken ones, which are compiled to 1's and 0's and run–woven?–on computers.

These videos demonstrate simple and Jacquard looms:

<center><iframe width="560" height="315" src="https://www.youtube.com/embed/K6NgMNvK52A" frameborder="0" allowfullscreen></iframe><iframe width="560" height="315" src="https://www.youtube.com/embed/UPuAdWYlr_8" frameborder="0" allowfullscreen></iframe></center>

This is another [great overview of industrial looms](https://www.youtube.com/watch?v=TyhDkd8Iabs&feature=youtu.be&t=56s) that takes you all the way from the basics to the state of the art.

# Computing

The _Central Processing Unit (CPU)_ can be thought of as a magic black box that takes an input and does something with it to produce an output. A simple adding computer might take two numbers as inputs, and output their sum. Digital computers don't use decimal numbers like we do, they use binary numbers. So, if you wanted to tell a computer to add 4 and 5, you'd have to supply their binary representations. We'd tell it to add 100 and 101.

Suppose the computer can also subtract numbers. So, if we provide it with two numbers, we need a way to tell it whether to add or subtract. Since we have just two jobs, we may conveniently use 1 to instruct it to add, and 0 to subtract. If we put together the instruction to add or subtract together with the numbers, we can form a sort of word for the computer:

	1100101: 1 (add) 100 (4) 101 (and 5)

Let's say our computer can add or subtract two positive numbers between 0 and 7 (7 in binary is 111, so we're limiting ourselves to 3 binary digits per number. We'll only ever need 7 binary digits, so we call it a 7 bit computer–(bi)nary digi(t). We could then give it a whole series of instructions, maybe in response to a person using our special calculator that has no 8's or 9's:

	0101010: 101 - 010: 5 - 2
	0010101: 010 - 101: 2 - 5
	1100100: 100 + 100: 4 + 4
	0111010: 111 - 010: 7 - 2

## Programs

Humans read and write computer programs using languages made of punctuation and words, instead of 1's and 0's. This is a C program that prints "Hello world!" on a computer screen–the canonical example when learning a new programming language:

    #include <stdio.h>
    
    int main (int argc, const char * argv[]) {
        printf("Hello, World!\n");
        return 0;
    }
    
Programs written in these so-called _high level_ languages are _compiled_ into a _low level_ language called _assembly_. Here's what the assembly for the above program might look like (generated using `cc -c helloworld.c && objdump --disassemble helloworld.o`):

	pushq	%rbp
	movq	%rsp, %rbp
	subq	$32, %rsp
	leaq	37(%rip), %rax
	movl	$0, -4(%rbp)
	movl	%edi, -8(%rbp)
	movq	%rsi, -16(%rbp)
	movq	%rax, %rdi
	movb	$0, %al
	callq	0 <_main+0x27>
	xorl	%ecx, %ecx
	movl	%eax, -20(%rbp)
	movl	%ecx, %eax
	addq	$32, %rsp
	popq	%rbp
	retq

However, we still have one more transformation before we can see what the CPU sees. Remember, the CPU works in bits, not these strange abbreviations. For instance, it doesn't know what to do with `subq	$32, %rsp` (subtract 32 from whatever value is in the stack pointer _register_, where a register is a place to store a number). Each computer chip defines an _instruction set architecture (ISA)_ that maps instructions like `subq` to a binary number called an _opcode_ (the opcode for `subq` is 01001000; an ISA with an 8 bit opcode can support at least 2^9 or 512 different operations), which is followed by the binary representation of the inputs (there are some exceptions, but they aren't important here). Here is the entire program in binary:

	01010101000000000000000000000000000000000000000000000000000000
	01001000100010011110010100000000000000000000000000000000000000
	10010001000001111101100001000000000000000000000000000000000000
	10010001000110100000101001001010000000000000000000000000000000
	11000111010001011111110000000000000000000000000000000000000000
	10001001011111011111100000000000000000000000000000000000000000
	10010001000100101110101111100000000000000000000000000000000000
	10010001000100111000111000000000000000000000000000000000000000
	10110000000000000000000000000000000000000000000000000000000000
	11101000000000000000000000000000000000000000000000000000000000
	11000111001001000000000000000000000000000000000000000000000000
	10001001010001011110110000000000000000000000000000000000000000
	10001001110010000000000000000000000000000000000000000000000000
	10010001000001111000100001000000000000000000000000000000000000
	10111010000000000000000000000000000000000000000000000000000000
	11000011000000000000000000000000000000000000000000000000000000

It might not produce an attractive woven tapestry, but it will print "Hello world!" on a computer screen!

## Modern CPUs

This list of 64 digit binary numbers might be fed into a 64 bit computer, like that of this Raspberry Pi: 

{% include 
	blog-post-image.html 
	source="raspberry-pi.png" 
	alt="A Raspberry Pi circuit board." %}
	
Visible lines emanate from the CPU chip, just to the right of the raspberry. These are like the warp threads, each carrying its bit value of 1 or 0 into the CPU for each clock cycle (pass of the weft). (Note that you might not see all 64 of the lines leading into the CPU, or others used for power or other controls; circuit boards are actually multiple layers, of which the Raspberry Pi has 6, each with its own separate design of circuits!)

Each tick of the computer's clock, the CPU goes through each of the steps to _fetch_ the next number, _decode_ the instruction, _execute_ it by potentially _reading_ numbers from registers or external memory and _writing_ back any result we need to keep around. Just like looms grew in complexity to the industrial machinery of today, modern CPU architectures go further than simply carrying out instructions one by one. Chips can coordinate different components to essentially execute multiple instructions simultaneously. This video describes the technique of "pipelining" the fetch-decode-execute-read/write cycle:

<center><iframe width="560" height="315" src="https://www.youtube.com/embed/eVRdfl4zxfI" frameborder="0" allowfullscreen></iframe></center>

The video describes a pipeline with 4 stages, whereas Intel's microarchitectures have upwards of 20! Pipelining itself can be further enhanced with techniques like branch prediction, out-of-order scoreboarding, pipeline interlock and stage balancing. Other facets of the CPU or ISA may be improved with extended instruction sets and SIMD (Single Instruction Multiple Data) vectorization. Even entirely separate chips with different types of microcomponents and architectures, like GPUs (Graphical Processor Units), are used to solve different types of problems. When you're doing billions or trillions of operations per second, having dedicated circuitry to work with particular kinds of numbers or other data makes a big difference.

# Wearing code on one's sleeves

While software written in high level language may not be as tangible as a t-shirt, computing is still as physical a phenomenon as it was when it was performed with an abacus or [stepped reckoner](https://en.wikipedia.org/wiki/Stepped_reckoner). The same electicity in bolts of lightning or the human body is harnessed in wildly complex ways to drive today's electronics. For a little more information on the history of computers and where the Jacquard loom fits in, see this [illustrated history of computers](http://www.computersciencelab.com/ComputerHistory/HistoryPt2.htm).
