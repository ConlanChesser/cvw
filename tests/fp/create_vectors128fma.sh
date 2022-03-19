#!/bin/sh

BUILD="./TestFloat-3e/build/Linux-x86_64-GCC"
OUTPUT="./vectors"

$BUILD/testfloat_gen -rnear_even f128_mulAdd > $OUTPUT/f128_mulAdd_rne.tv
$BUILD/testfloat_gen -rminMag f128_mulAdd > $OUTPUT/f128_mulAdd_rz.tv
$BUILD/testfloat_gen -rmax f128_mulAdd > $OUTPUT/f128_mulAdd_ru.tv
$BUILD/testfloat_gen -rmin f128_mulAdd > $OUTPUT/f128_mulAdd_rd.tv
$BUILD/testfloat_gen -rnear_maxMag f128_mulAdd > $OUTPUT/f128_mulAdd_rnm.tv

# format: X_Y_Z_answer_flags_Frm_Fmt
sed -i 's/ /_/g' $OUTPUT/f128_mulAdd_rne.tv
sed -ie 's/$/_0/' $OUTPUT/f128_mulAdd_rne.tv
sed -ie 's/$/_3/' $OUTPUT/f128_mulAdd_rne.tv

sed -i 's/ /_/g' $OUTPUT/f128_mulAdd_rz.tv
sed -ie 's/$/_1/' $OUTPUT/f128_mulAdd_rz.tv
sed -ie 's/$/_3/' $OUTPUT/f128_mulAdd_rz.tv

sed -i 's/ /_/g' $OUTPUT/f128_mulAdd_ru.tv
sed -ie 's/$/_3/' $OUTPUT/f128_mulAdd_ru.tv
sed -ie 's/$/_3/' $OUTPUT/f128_mulAdd_ru.tv

sed -i 's/ /_/g' $OUTPUT/f128_mulAdd_rd.tv
sed -ie 's/$/_2/' $OUTPUT/f128_mulAdd_rd.tv
sed -ie 's/$/_3/' $OUTPUT/f128_mulAdd_rd.tv

sed -i 's/ /_/g' $OUTPUT/f128_mulAdd_rnm.tv
sed -ie 's/$/_4/' $OUTPUT/f128_mulAdd_rnm.tv
sed -ie 's/$/_3/' $OUTPUT/f128_mulAdd_rnm.tv