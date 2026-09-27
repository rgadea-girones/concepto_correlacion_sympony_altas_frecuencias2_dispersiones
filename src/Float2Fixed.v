`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Roman Lysecky, Lance Saldanha, Varadaraj Kamath Nileshwar,
//                Jovan Vance, David Schwartz
//
// Module Name  : Float2Fixed
//
// Description  : Floating point to fixed point converter
//
// Date modified: 11.14.2008 : Initial Version
//
// 					 1.16.2014 : Bug Fix - Modified size for ShiftAmount 
//                             in FixedShiftCalc (FixedShiftCalc.v) to ensure 
//                             sufficient bits for exponent values greater  
//                             than RADIXPOINTSIZE. 
//                             NOTE: ShiftAmount must be equal
//                             to max(EXPONENTBITS, RADIXPOINTSIZE) + 1.
//
// 					 1.16.2014 : Modified calculation for OutShiftAmount in
//                             FixedShiftCalc (FixedShiftCalc.v) to correct
//                             output result for floating point values smaller
//                             than the smallest representable fixed point value. 
//                             Modified design will output a fixed point value of 0 
//                             in this situation.
//										 
//-----------------------------------------------------------------------------

module Float2Fixed (
    InFloat,
    InRadixPoint,
    OutFixed,
    OutOverflow,
    OutException
    );

    //-------------------------------------------------------------------------
    //                     Parameter Definitions
    //-------------------------------------------------------------------------
    // Width of floating point output
    parameter FLOATSIZE         = 32;
    
    // Width of OutFixed point input
    parameter FIXEDSIZE         = 64;
    
    // Width needed to represent radix point
    parameter RADIXPOINTSIZE    = 6;
    
    // Number of bits used to represent the exponent
    parameter EXPONENTBITS      = 8;
    
    // Number of bits used to represent the mantissa
    parameter MANTISSABITS      = 23;

    // Number of bits used to represent the overflow
    parameter OVERFLOWBITS      = 6;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------

    // Floating point input
    input [FLOATSIZE-1:0] InFloat;

    // RadixPoint position from right
    input [RADIXPOINTSIZE-1:0] InRadixPoint;

    // Fixed point output
    output [FIXEDSIZE-1:0] OutFixed;
    
    // Overflow bits
    output [RADIXPOINTSIZE-1:0] OutOverflow;
    
    // Output flag indicating that there has been an exception
    output OutException;

    //-------------------------------------------------------------------------
    //                     Internal Signals (wire & reg) declaration
    //-------------------------------------------------------------------------
    wire Zero;
    wire Normal;

    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------
    // Module to handle Normal floating point numbers
    NormalCases #(
        .FLOATSIZE      (FLOATSIZE      ),
        .FIXEDSIZE      (FIXEDSIZE      ),
        .RADIXPOINTSIZE (RADIXPOINTSIZE ),
        .EXPONENTBITS   (EXPONENTBITS   ),
        .MANTISSABITS   (MANTISSABITS   ),
        .OVERFLOWBITS	(OVERFLOWBITS	)
        ) 
    Normal_Inst0 (
        .InFloat        (InFloat        ),
        .InRadixPoint   (InRadixPoint   ),
        .InNormal       (Normal         ),
        .InZero         (Zero           ),
        .OutFixed       (OutFixed       ),
        .OutOverflow    (OutOverflow    )
        );
    
    // Module to handle Special floating point numbers
    SpecialCases #(
        .FLOATSIZE      (FLOATSIZE      ),
        .FIXEDSIZE      (FIXEDSIZE      ),
        .RADIXPOINTSIZE (RADIXPOINTSIZE ),
        .EXPONENTBITS   (EXPONENTBITS   ),
        .MANTISSABITS   (MANTISSABITS   )
        ) 
    Special_Inst0 (
        .InFloat        (InFloat        ),
        .OutException   (OutException   ),
        .OutNormal      (Normal         ),
        .OutZero        (Zero           )
        );

endmodule