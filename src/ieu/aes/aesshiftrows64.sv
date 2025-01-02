///////////////////////////////////////////
// aesshiftrows64.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: aesshiftrow for taking in first Data line
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-25 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module aesshiftrows64(
   /* verilator lint_off UNUSEDSIGNAL */
   input  logic [127:0] a, 
   /* verilator lint_on UNUSEDSIGNAL */
   output logic [63:0] y
);
		    
   assign y = {a[31:24],   a[119:112], a[79:72],   a[39:32],
               a[127:120], a[87:80],   a[47:40],   a[7:0]};   
endmodule
