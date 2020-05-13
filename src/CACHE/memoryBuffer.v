module memoryBuffer(
    input clk, rst,
    input [31:0] address, dataIn,
    input write, read,
    output reg [31:0] dataHit,
    output [31:0] addressToMemory, dataToMemory,
    output reg hit, 
    output full, empty
);
    reg [3:0] pointer; // указатель записи
    reg [64:0] buffer [0:7]; // буфер на 8 единиц по 1 + 32 + 32 (Актуальность + Адрес + Данные)

    assign full = pointer == 4'd8; // Если 8 записей в буфере — он полон
    assign empty = pointer == 4'd0;
    assign {addressToMemory, dataToMemory} = buffer[0];
    
    // Если есть hit по тегу — возвращаем его данные
    always @(*) begin
        case ({1'b1, address})
            buffer[0][64:32]: {hit, dataHit} = { 1'd1, buffer[0][31:0] };
            buffer[1][64:32]: {hit, dataHit} = { 1'd1, buffer[1][31:0] };
            buffer[2][64:32]: {hit, dataHit} = { 1'd1, buffer[2][31:0] };
            buffer[3][64:32]: {hit, dataHit} = { 1'd1, buffer[3][31:0] };
            buffer[4][64:32]: {hit, dataHit} = { 1'd1, buffer[4][31:0] };
            buffer[5][64:32]: {hit, dataHit} = { 1'd1, buffer[5][31:0] };
            buffer[6][64:32]: {hit, dataHit} = { 1'd1, buffer[6][31:0] };
            buffer[7][64:32]: {hit, dataHit} = { 1'd1, buffer[7][31:0] };
            default: {hit, dataHit} = { 1'd0, 32'd0 };
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            for (integer i = 0; i < 8; i = i + 1) buffer[i] <= 65'd0;
            pointer <= 4'd0;
        end
        else if (write) begin
            buffer[pointer] <= {1'd1, address, dataIn};
            pointer += 1;
        end
        else if (pointer != 4'd0 && read) begin
            for(integer i = 0; i < 7; i=i+1) buffer[i][64:0] <= buffer[i+1][64:0];
            buffer[7] <= 65'd0;
            pointer -= 1;
        end
    end

endmodule