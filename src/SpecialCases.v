`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Lysecky, R., Saldanha, L., Kamath Nileshwar, V.
//
// Module Name  : SpecialCases
//
// Description  : Detects the occurence of special case floating point 
//                representations like positive and negative zero, positive and
//                negative infinity, Not a number and Denormalized numbers
//
// Date modified: 11.14.2008
//-----------------------------------------------------------------------------

module SpecialCases (
    InFloat,
    OutException,
    OutZero,
    OutNormal
    );
  
    //-------------------------------------------------------------------------
    //                     Parameter Definitions
    //-------------------------------------------------------------------------
    // Width of floating point output
    parameter FLOATSIZE         = 32;
    
    // Width of OutFixed point input
    parameter FIXEDSIZE         = 32;
    
    // Width needed to represent radix point
    parameter RADIXPOINTSIZE    = 6;
    
    // Number of bits used to represent the exponent
    parameter EXPONENTBITS      = 8;
    
    // Number of bits used to represent the mantissa
    parameter MANTISSABITS      = 23;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------

    // Floating point input
    input [(FLOATSIZE-1):0] InFloat;
    
    // Output flag indicating that the floating point input is normalized
    output reg OutNormal;
    
    // Output flag indicating the occurence of an exception
    output reg OutException;
    
    // Output flag indicating the occurence of a positive or negative zero
    output reg OutZero;

    //-------------------------------------------------------------------------
    //                     Internal Signals (wire & reg) declaration
    //-------------------------------------------------------------------------
    wire [EXPONENTBITS-1:0] Exponent;
    wire [MANTISSABITS-1:0] Mantissa;

    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------

    assign Exponent = InFloat[FLOATSIZE-2:MANTISSABITS];
    assign Mantissa = InFloat[MANTISSABITS-1:0];

    always @ (Exponent, Mantissa)
    begin
        // Input is zero if all bits are zero
        // Zero is also asserted in case of infinity and Not a Number so that
        // the output can be propogated as zero
        // In case of Infinity, the exponent component is set to all 1s
        // and mantissa is set to zero
        // In case of NaN, the exponent component is all 1s but mantissa
        // is a non-zero value
        OutZero      <= ( |Exponent == 1'b0 && |Mantissa == 1'b0 ) || &Exponent;
        
        // Input is denormalized if all bits of exponent are zero but
        // mantissa is not zero. Normalized number by taking inverse of the
        // check for denormalized number
        OutNormal    <= ~( |Exponent == 1'b0 && |Mantissa == 1'b1 );
        
        // Exception is asserted in case of infinity (positive and negative)
        // and also in case of Not a Number (NaN). Both of them have the common
        // property of the exponent being set to all 1s
        OutException <= &Exponent;
    end

endmodule
