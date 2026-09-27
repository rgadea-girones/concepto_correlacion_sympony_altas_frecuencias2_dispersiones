`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Project      : Arizona Float<->Fixed Hardware Library (AFFHL)
//
// Authors      : Lysecky, R., Saldanha, L., Kamath Nileshwar, V.
//
// Module Name  : NormalCases
//
// Description  : Floating to fixed point conversion for normalized numbers
//
// Date modified: 11.14.2008 : Initial Version
//                07.18.2010 : Added 2 new ports to Overflow module
//-----------------------------------------------------------------------------

module NormalCases (
    InFloat,
    InRadixPoint,
    InNormal,
    InZero,
    OutFixed,
    OutOverflow
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

    // Number of bits used to represent the overflow
    parameter OVERFLOWBITS      = 6;

    //-------------------------------------------------------------------------
    //                     Port Definitions
    //-------------------------------------------------------------------------

    // Floating point input
    input [FLOATSIZE-1:0] InFloat;

    // RadixPoint position from right
    input [RADIXPOINTSIZE-1:0] InRadixPoint;

    // Input indicating that the input is zero
    input InZero;

    // Input flag indicating whether the input is normalized or denormalized
    input InNormal;

    // Fixed point output
    output reg [FIXEDSIZE-1:0] OutFixed;

    // Overflow bits
    output [RADIXPOINTSIZE-1:0] OutOverflow;

    //-------------------------------------------------------------------------
    //                     Internal Signals (wire & reg) declaration
    //-------------------------------------------------------------------------
    // Direction in which the number is to be shifted
    // 1 - Right shift
    // 0 - Left shift
    wire ShiftDirection;

    // Shift value
    wire [RADIXPOINTSIZE-1:0] ShiftAmount;

    // Unsigned fixed point number
    wire [FIXEDSIZE-1:0] UFixed;

    // Sign bit
    wire SignBit;

    // Exponent
    wire [EXPONENTBITS-1:0] Exponent;

    // Normalized floating point value
    // 0.xxxx for a denormalized floating point number
    // 1.xxxx for a normal floating point number
    wire [MANTISSABITS:0] NormFloat;

    // Temporary variable to store Fixed point output
    // This is ANDed with the zero input
    reg  [FIXEDSIZE-1:0] SignedFixed;

    // Loop variable
    integer i;

    //-------------------------------------------------------------------------
    //                     Assignments and Statement Blocks
    //-------------------------------------------------------------------------

    assign SignBit   = InFloat[FLOATSIZE-1];

    assign Exponent  = InFloat[FLOATSIZE-2:FLOATSIZE-EXPONENTBITS-1];

    assign NormFloat = {InNormal, InFloat[MANTISSABITS-1:0]};

    // Module to calculate Shift value
    FixedShiftCalc #(
        .FLOATSIZE          (FLOATSIZE      ), 
        .FIXEDSIZE          (FIXEDSIZE      ), 
        .RADIXPOINTSIZE     (RADIXPOINTSIZE ), 
        .EXPONENTBITS       (EXPONENTBITS   ), 
        .MANTISSABITS       (MANTISSABITS   )
        )
    Inst_FixedShiftCalc (
        .InExponent         (Exponent       ),
        .InRadixPoint       (InRadixPoint   ),
        .InNormal           (InNormal       ),
        .OutShiftAmount     (ShiftAmount    ),
        .OutShiftDirection  (ShiftDirection )
        );

    // Module to shift left or right based on computed shift value
    FixedShifter #(
        .FLOATSIZE          (FLOATSIZE      ),
        .FIXEDSIZE          (FIXEDSIZE      ),
        .RADIXPOINTSIZE     (RADIXPOINTSIZE ),
        .EXPONENTBITS       (EXPONENTBITS   ),
        .MANTISSABITS       (MANTISSABITS   )
        )
    Inst_FixedShifter (
        .InNormFloat        (NormFloat      ),
        .InShiftAmount      (ShiftAmount    ),
        .InShiftDirection   (ShiftDirection ),
        .OutUFixed          (UFixed         )
        );

    // Module to calculate number of extra bits needed to avoid overflow
    Overflow #(
        .FLOATSIZE          (FLOATSIZE      ),
        .FIXEDSIZE          (FIXEDSIZE      ),
        .RADIXPOINTSIZE     (RADIXPOINTSIZE ),
        .EXPONENTBITS       (EXPONENTBITS   ),
        .MANTISSABITS       (MANTISSABITS   ),
        .OVERFLOWBITS       (OVERFLOWBITS   )
        )
    Inst_Overflow (
        .InShiftAmount      (ShiftAmount    ),
        .InShiftDirection   (ShiftDirection ),
        .InNormal           (InNormal       ),
        .InExponent         (Exponent       ),
        .InRadixPoint       (InRadixPoint   ),
        .OutOverflow        (OutOverflow    )
        );

    // Convert to signed representation 
    always @ (UFixed, SignBit)
    begin
        if(SignBit == 1)
        begin
            SignedFixed <= -UFixed;
        end
        else
        begin
            SignedFixed <= UFixed;
        end
    end

    // Final output is ANDed with the inverse of the zero input so that
    // output is made zero in case input is zero
    always @ (SignedFixed, InZero)
    begin
        for (i = 0; i < FIXEDSIZE; i = i + 1)
        begin
            OutFixed[i] <= SignedFixed[i] & (~InZero);
        end
    end

endmodule
