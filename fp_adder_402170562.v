`default_nettype none
module fp_adder (a,b,s);
input wire [31:0] a;
input wire [31:0] b;
output wire[31:0] s;


//------------------------------------- wire deceleration
wire sign_A;
wire sign_B;
wire [7:0] expBiased_A;
wire [7:0] expBiased_B;
wire [22:0] frac_A;
wire [22:0] frac_B;
wire hiddenBit_A;
wire hiddenBit_B;
wire [25:0] mantis_A;
wire [25:0] mantis_B;

wire [7:0] exponent_A;
wire [7:0] exponent_B;
wire [8:0] expDifferance;

wire [7:0] e1; //bigger exponent refereancing example in slides.
wire [25:0] a1; //the chad mantis
wire [25:0] a2; //the mantis that needs to get shifted
wire [8:0] shiftAmount; //set to be 8 bits long because we are overriding it to be read as a the aboslute amount of differance in exponents.
//actually we set it to be 9 bits because 8 bits can be interpretted as negative and i'm not sure

wire [25:0] shifted_a2_frac;
wire borrow;
wire sAu3;
wire sAo25;
wire sign_a1;
wire sign_a2;
wire hiddenBit_a1;
wire hiddenBit_a2;
wire sticky_a2;
wire[26:0] before_2cse_a1;
wire[26:0] before_2cse_a2;
wire [28:0] full_a1;
wire [28:0] full_a2;

wire [28:0] bigadder_output;
wire sign_output;
wire [28:0] output_ase2c;

wire [7:0] exponent_output;

wire [7:0] exponent_output2;

wire [6:0] where1;
wire hiddenBit_output;
wire fm23;
wire R;
wire G;
wire S;
wire GorSorR;
wire RorS;
wire [1:0] rounding24;
wire [1:0] rounding12;
wire [1:0] rounding051;
wire [22:0] fraction_out;

wire [22:0] fraction24;
wire [22:0] fraction12;
wire [22:0] fraction051;
wire [22:0] fraction005;

wire [23:0] fraction24_ar; // one bit extra in case we get another exponent
wire [23:0] fraction12_ar;
wire [23:0] fraction051_ar;

wire [22:0] fraction24_arn;
wire [22:0] fraction12_arn;
wire [22:0] fraction051_arn;

wire [7:0] exponent_output24;
wire [7:0] exponent_output12;
wire [7:0] exponent_output051;

wire flag_cant;
wire [22:0] fraction_out_def;


//--------------------------------------------------------- 

//-------------------------------------- extraction logic

assign expBiased_A = a[30:23];
assign expBiased_B = b[30:23];
assign frac_A = a[22:0];
assign frac_B = b[22:0];
assign sign_A = (frac_A==0 & expBiased_A==0)? 0 : a[31];
assign sign_B = (frac_B==0 & expBiased_B==0)? 0 : b[31];
assign hiddenBit_A = (expBiased_A != 8'b0);
assign hiddenBit_B = (expBiased_B != 8'b0);
assign mantis_A = {hiddenBit_A, frac_A, 2'b00};
assign mantis_B = {hiddenBit_B, frac_B, 2'b00};
assign exponent_A = (~hiddenBit_A ? 1'b1 : expBiased_A);
assign exponent_B = (~hiddenBit_B ? 1'b1 : expBiased_B);
assign expDifferance = exponent_A - exponent_B;
//update rightside and leftside
assign e1 = (borrow ? exponent_B : exponent_A);

assign a1 = ((expDifferance == 0) ? 
            ( (mantis_A >= mantis_B) ? mantis_A : mantis_B )  :// because of e==1 originaly vs when we attachet it to be 1 has different hidden bits
            (borrow ? mantis_B : mantis_A));           // we should compare mantises that we added hidden bit to instead of comparing fractions
assign a2 = ((expDifferance == 0) ? 
            ( (mantis_A >= mantis_B) ? mantis_B : mantis_A )  :
            (borrow ? mantis_A : mantis_B));

assign sign_a1 = ((expDifferance == 0) ? 
            ( (mantis_A >= mantis_B) ? sign_A : sign_B )  :
            (borrow ? sign_B : sign_A));

assign sign_a2 = ((expDifferance == 0) ? 
            ( (mantis_A >= mantis_B) ? sign_B : sign_A )  :
            (borrow ? sign_A : sign_B));

assign hiddenBit_a1 = (mantis_A == a1) ? hiddenBit_A : hiddenBit_B;
assign hiddenBit_a2 = (mantis_B == a2) ? hiddenBit_B : hiddenBit_A;
//shift amount and sticky extraction
assign borrow = expDifferance[8];
assign shiftAmount = (borrow ? (~expDifferance+1) : expDifferance); // what if shift amount == 0?

assign sAo25 = (shiftAmount>25);
assign sAu3 = (shiftAmount<3);
assign sticky_a2 = (sAo25) ? |a2[25:2] :               // 1'b1 <<shiftAmount - 1'b1 whould produce :   0001<..shiftAmount..>1
            (sAu3) ? 1'b0 :
                | (a2[25:2] & ((24'b1 << shiftAmount-2) - 1'b1 )); // then bitwise and will produce only the bits that would be deleted!
//we should exclue G and R from sticky bit calculations there for we add -2 and add a condition to if sA<=2 it returns zero.
 
assign shifted_a2_frac = a2[25:0] >> shiftAmount; //set to conclude 2 of the last bits

assign before_2cse_a1 = {a1,1'b0};
assign before_2cse_a2 = {shifted_a2_frac,sticky_a2};

assign full_a1 = (sign_a1) ? {sign_a1, sign_a1, ~before_2cse_a1 + 1'b1} : {sign_a1, sign_a1, before_2cse_a1};
assign full_a2 = (sign_a2) ? {sign_a2, sign_a2, ~before_2cse_a2 + 1'b1} : {sign_a2, sign_a2, before_2cse_a2};

assign bigadder_output = full_a1 + full_a2;
assign sign_output = (frac_A==frac_B & expBiased_A==expBiased_B & sign_A!=sign_a2)? 0 : sign_a1; //80000000 t0 00000000
//should sticky also be two's complimented?
//here it is!
assign output_ase2c = (sign_output)? (~bigadder_output + 1) : bigadder_output;


assign where1 = (output_ase2c[27]) ? 1 :
                (output_ase2c[26]) ? 2 :
                (output_ase2c[25]) ? 3 :
                (output_ase2c[24]) ? 4 :    
                (output_ase2c[23]) ? 5 :    
                (output_ase2c[22]) ? 6 :    
                (output_ase2c[21]) ? 7 :    
                (output_ase2c[20]) ? 8 :    
                (output_ase2c[19]) ? 9 :    
                (output_ase2c[18]) ? 10 :    
                (output_ase2c[17]) ? 11 :    
                (output_ase2c[16]) ? 12 :    
                (output_ase2c[15]) ? 13 :    
                (output_ase2c[14]) ? 14 :    
                (output_ase2c[13]) ? 15 :    
                (output_ase2c[12]) ? 16 :    
                (output_ase2c[11]) ? 17 :    
                (output_ase2c[10]) ? 18 :   
                (output_ase2c[9]) ? 19 :    
                (output_ase2c[8])  ? 20 :    
                (output_ase2c[7])  ? 21 :    
                (output_ase2c[6])  ? 22 :    
                (output_ase2c[5])  ? 23 :    
                (output_ase2c[4])  ? 24 :       
                (output_ase2c[3])  ? 25 :    
                (output_ase2c[2])  ? 26 :    
                (output_ase2c[1])  ? 27 :     
                (output_ase2c[0])  ? 28 : 0;
//what if no leading one was there?
assign exponent_output = (where1==1) ? e1+1'b1:
                            (where1==2) ? e1:
                        (where1-2<e1) ? e1-(where1-2): //we can't shift fully
                        1'b1;
assign flag_cant = (e1==1 & where1!=1)? 1 : 0;
assign hiddenBit_output = (where1<3) ? 1 : 
                          (where1-2>=e1) ? 0 : 1;

assign S = output_ase2c[0];
assign R = output_ase2c[1];
assign G = output_ase2c[2];
assign fm23 = output_ase2c[3];
assign GorSorR = G|R|S;
assign RorS = R|S;
assign rounding24 = {fm23,GorSorR};
assign rounding12 = {G,RorS};
assign rounding051 = {R,S};

assign fraction24 = {1'b0,output_ase2c[26:4]}; //where1=1
assign fraction12 = {1'b0,output_ase2c[25:3]}; //where1=2
assign fraction051 = {1'b0,output_ase2c[24:2]};//where1=3
 //fraction005 needs to be updated directly depening on where1 
assign fraction24_ar = (~rounding24[1])? fraction24 :
                        (rounding24 == 2'b11)? (fraction24+1): //tied
                        (~fraction24[0]) ? fraction24 :
                        fraction24+1;
                        
assign fraction12_ar = (~rounding12[1])? fraction12 :
                        (rounding12 == 2'b11)? (fraction12 +1):
                        (~fraction12[0]) ? fraction12 :
                        (fraction12+1);

assign fraction051_ar = (~rounding051[1])? fraction051 :
                        (rounding051 == 2'b11)? (fraction051 +1):
                        (~fraction051[0]) ? fraction051 :
                        (fraction051+1);

assign fraction24_arn = fraction24_ar[22:0];
assign exponent_output24 = (fraction24_ar[23])? (exponent_output+1) : exponent_output;

assign fraction12_arn = fraction12_ar[22:0];
assign exponent_output12 = (fraction12_ar[23])? (exponent_output+1) : exponent_output;

assign fraction051_arn = fraction051_ar[22:0];  
assign exponent_output051 = (fraction051_ar[23])? (exponent_output+1) : exponent_output;

assign fraction_out = (where1 == 1) ? fraction24_arn :
                        (where1==2) ? fraction12_arn :
                        (where1==3) ? fraction051_arn :
                        (where1-2<=e1-1) ?
                        ((where1==4) ? ((hiddenBit_output)? output_ase2c[23:1] : output_ase2c[24:2] ):
                            (where1==5) ? ((hiddenBit_output)? output_ase2c[22:0] : output_ase2c[23:1] ):
                            (where1==6) ? ((hiddenBit_output)? {output_ase2c[21:0],1'b0} : output_ase2c[22:0] ):
                            (where1==7) ? ((hiddenBit_output)? {output_ase2c[20:0],2'b0} : {output_ase2c[21:0],1'b0} ):
                            (where1 == 8) ? ((hiddenBit_output) ? {output_ase2c[19:0], 3'b0} : {output_ase2c[20:0], 2'b0}) :
                            (where1 == 9) ? ((hiddenBit_output) ? {output_ase2c[18:0], 4'b0} : {output_ase2c[19:0], 3'b0}) :
                            (where1 == 10) ? ((hiddenBit_output) ? {output_ase2c[17:0], 5'b0} : {output_ase2c[18:0], 4'b0}) :
                            (where1 == 11) ? ((hiddenBit_output) ? {output_ase2c[16:0], 6'b0} : {output_ase2c[17:0], 5'b0}) :
                            (where1 == 12) ? ((hiddenBit_output) ? {output_ase2c[15:0], 7'b0} : {output_ase2c[16:0], 6'b0}) :
                            (where1 == 13) ? ((hiddenBit_output) ? {output_ase2c[14:0], 8'b0} : {output_ase2c[15:0], 7'b0}) :
                            (where1 == 14) ? ((hiddenBit_output) ? {output_ase2c[13:0], 9'b0} : {output_ase2c[14:0], 8'b0}) :
                            (where1 == 15) ? ((hiddenBit_output) ? {output_ase2c[12:0], 10'b0} : {output_ase2c[13:0], 9'b0}) :
                            (where1 == 16) ? ((hiddenBit_output) ? {output_ase2c[11:0], 11'b0} : {output_ase2c[12:0], 10'b0}) :
                            (where1 == 17) ? ((hiddenBit_output) ? {output_ase2c[10:0], 12'b0} : {output_ase2c[11:0], 11'b0}) :
                            (where1 == 18) ? ((hiddenBit_output) ? {output_ase2c[9:0], 13'b0} : {output_ase2c[10:0], 12'b0}) :
                            (where1 == 19) ? ((hiddenBit_output) ? {output_ase2c[8:0], 14'b0} : {output_ase2c[9:0], 13'b0}) :
                            (where1 == 20) ? ((hiddenBit_output) ? {output_ase2c[7:0], 15'b0} : {output_ase2c[8:0], 14'b0}) :
                            (where1 == 21) ? ((hiddenBit_output) ? {output_ase2c[6:0], 16'b0} : {output_ase2c[7:0], 15'b0}) :
                            (where1 == 22) ? ((hiddenBit_output) ? {output_ase2c[5:0], 17'b0} : {output_ase2c[6:0], 16'b0}) :
                            (where1 == 23) ? ((hiddenBit_output) ? {output_ase2c[4:0], 18'b0} : {output_ase2c[5:0], 17'b0}) :
                            (where1 == 24) ? ((hiddenBit_output) ? {output_ase2c[3:0], 19'b0} : {output_ase2c[4:0], 18'b0}) :
                            (where1 == 25) ? ((hiddenBit_output) ? {output_ase2c[2:0], 20'b0} : {output_ase2c[3:0], 19'b0}) :
                            (where1 == 26) ? ((hiddenBit_output) ? {output_ase2c[1:0], 21'b0} : {output_ase2c[2:0], 20'b0}) :
                            (where1 == 27) ? ((hiddenBit_output) ? {output_ase2c[0], 22'b0} : {output_ase2c[1:0], 21'b0}) :
                            (where1 == 28) ? ((hiddenBit_output) ? 23'b0 : {output_ase2c[0], 22'b0}) :
                            0
                        ) : ((e1>4) ? (output_ase2c << (e1-4)) :
                            (e1==4)? (output_ase2c[22:0]) :
                            (e1==3)? (output_ase2c[23:1]) :
                            (e1==2)? (output_ase2c[24:2]) : 0
                        );

assign exponent_output2 =   (fraction_out==0 & (exponent_output == 1 | exponent_output == 0)) ? 0 : 
                            (exponent_output == 8'h01 & (~hiddenBit_output))? 0 : exponent_output;
// i might need to change this. what i did was  in page3 of debug
assign fraction_out_def = (flag_cant) ?  fraction12_arn : fraction_out;

assign s = (where1==1)? {sign_output, exponent_output24, fraction_out_def} :
            (where1==2)? {sign_output, exponent_output12, fraction_out_def} :
             (where1==3 & e1!=1)? {sign_output, exponent_output051, fraction_out_def} :
             {sign_output, exponent_output2, fraction_out_def};
// assign s = {sign_output, exponent_output2, fraction_out_def};


//--------------------------------------------------------- 


endmodule   