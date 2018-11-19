defmodule Worker do
    def init do 
        case Enum.random(Enum.to_list(0..100)) do
            random when random > 80 -> IO.puts "Crash"
            IO.puts random
		:crash
            random when random > 50 -> IO.puts "Omission"
            IO.puts random
		:omission
            random when random > 25 -> IO.puts "Timing"
            IO.puts random
		:timing
            random -> IO.puts "No fault"
            IO.puts random
		:no_fault
        end
    end  

    defp lista_divisores_propios(_, 0) do
        []
    end
    
    defp lista_divisores_propios(_, 1) do
        [1]
    end
    
    defp lista_divisores_propios(n, i) when i > 1 do
        if rem(n, i)==0, do: [i] ++ lista_divisores_propios(n, i - 1), else: lista_divisores_propios(n, i - 1)
    end
        
    def lista_divisores_propios(n) do
        lista_divisores_propios(n, n - 1)
    end

    defp suma_divisores_propios(_, 0) do
        0
    end
    
    defp suma_divisores_propios(_, 1) do
        1
    end
    
    defp suma_divisores_propios(n, i) when i > 1 do
        if rem(n, i)==0, do: i + suma_divisores_propios(n, i - 1), else: suma_divisores_propios(n, i - 1)
    end
        
    def suma_divisores_propios(n) do
        suma_divisores_propios(n, n - 1)
    end
    
    def suma(lista) do
        List.foldl(lista, 0, fn x, acc -> x + acc end)
    end
    
    def loop(numero) do
        loopI(init(), numero)
    end
  
    defp loopI(worker_type, numero) do
        delay = case worker_type do
            :crash -> System.halt()
            :timing -> Enum.random(Enum.to_list(0..100))*1000
            _ ->  0
        end
        Process.sleep(delay)
        receive do
            {:req, m_pid, m} -> 
                IO.puts m
                case numero do
                    1 -> if (((worker_type == :omission) and (Enum.random(Enum.to_list(0..100)) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)), do: send m_pid, {lista_divisores_propios(m)}
                    2 -> if (((worker_type == :omission) and (Enum.random(Enum.to_list(0..100)) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)), do: send m_pid, {suma_divisores_propios(m)}
                    3 -> if (((worker_type == :omission) and (Enum.random(Enum.to_list(0..100)) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)), do: send m_pid, {suma(m)}
                end
        end
        loopI(worker_type, numero)
    end
end
