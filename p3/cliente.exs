defmodule Cliente do
    def init(master_pid, inicio, fin) do
        send master_pid, {self(), Enum.to_list(inicio..fin)}
        receive do
            {result} ->
                IO.puts "Recibidos los resultados"
                init(master_pid, inicio, fin)
        end
    end
end
