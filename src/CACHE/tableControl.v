// Таблица управления кэша
// Каждая линия (8 линий) имеет вид:
// | v |    tag    | v |    tag    |
// 
// v    1bit    бит актуальности
// tag  24bit   тег блока данных
//
module tableControl(
    input clk, rst,
    input write, pos,
    input [2:0] lineWrite, lineRead,
    input [23:0] tagWrite, tagRead,
    output hit,
    output channel // Для выбора нужного слова (из канала) в таблице данных
);
    // Таблица; линия размером (1 + 1 + 24 + 1 + 24) = 51
    // tab[i][23:0] — tag1
    // tab[i][24] — v1
    // tab[i][48:25] — tag2
    // tab[i][49] — v2
    reg [49:0] tab [0:7];

    // если tag1 или tag2 равны входящему тегу + данные по tag1 tag2 акутальны
    assign channel = ((tagRead == tab[lineRead][48:25]) && tab[lineRead][49]);
    assign hit = ((tagRead == tab[lineRead][23:0]) && tab[lineRead][24]) || channel;

    // Сброс или Чтение
    always @(posedge clk) begin
        if (rst) for (integer i = 0; i < 51; i = i + 1)
            tab[i] <= 51'd0;
        else if (write) begin
            if (pos)    tab[lineWrite][49:25] <= {1'b1, tagWrite}; // v2 | tag2 <= actual | tag (if pos == 1)
            else        tab[lineWrite][24:0] <= {1'b1, tagWrite}; // v1 | tag1 <= actual | tag
        end
    end

endmodule


// module tester;
//     reg clk, rst, write;
//     reg [2:0] line;
//     reg [23:0] tag;
//     wire hit;

//     tableControl tc (.*);

//     always #1 clk = !clk;
//     initial begin
//         $dumpfile("dump");
//         $dumpvars(0, tester);
//         clk = 0;
//         rst = 1;
//         #2 rst = 0;
//         line = 3'd4;
//         tag = 24'd31;
//         write = 1'b1;
//         #2;
//         write = 1'b0;
//         #4;
//         line = 3'd7;
//         #16 $finish;
//     end

// endmodule