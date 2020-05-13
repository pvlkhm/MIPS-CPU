// Таблица данных кэша
// Каждая линия (8 линий) имеет вид:
// 16 слов по 32bit (Разбитых на две группы по 8 — для каждого канала
// | 32bit | 32bit | 32bit | 32bit | 32bit | 32bit | 32bit | 32bit |  +  -//-
// 
module tableData(
    input clk, rst,
    input update, channel,  // При чтении/обновлении необходим (идет из control модуля таблицы, где именно совпал тег)
    input write, pos,
    input [2:0] lineWrite, lineRead,
    input [2:0] wordWrite, wordRead,
    input [31:0] dataIn,
    output [31:0] data
);
    // Таблица размером (8 * 32) + (8 * 32) = 512
    reg [511:0] tab [0:7];

    // Если channel == 1 -> берем слова из [511:256], иначе из [255:0]
    // Слова индексируем по word (от 0 до 7)
    assign data =   channel ? 
                    tab[lineRead][(256 + wordRead*32) +: 32] :
                    tab[lineRead][wordRead*32 +: 32];

    // Сброс или чтение
    always @(posedge clk) begin
        if (rst) for (integer i = 0; i < 512; i = i + 1)
            tab[i] <= 512'd0;
        else if (write) begin
            if (pos)    tab[lineWrite][(256 + wordWrite*32) +: 32] <= dataIn;
            else        tab[lineWrite][wordWrite*32 +: 32] <= dataIn;
        end
        else if (update) begin
            if (channel)    tab[lineWrite][(256 + wordWrite*32) +: 32] <= dataIn;
            else            tab[lineWrite][wordWrite*32 +: 32] <= dataIn;
        end       
    end

endmodule