defmodule Worker do
    def init do 
        case :random.uniform(100) do
            random when random > 80 -> :crash
            random when random > 50 -> :omission
            random when random > 25 -> :timing
            _ -> :no_fault
        end
    end  

    defp lista_divisores_propios(_, 1) do
        1
    end
    
    defp lista_divisores_propios(n, i) when i > 1 do
        if rem(n, i)==0, do: [i] ++ lista_divisores_propios(n, i - 1), else: lista_divisores_propios(n, i - 1)
    end
        
    def lista_divisores_propios(n) do
        lista_divisores_propios(n, n - 1)
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
            :crash -> if :random.uniform(100) > 75, do: :infinity
            :timing -> :random.uniform(100)*1000
            _ ->  0
        end
        Process.sleep(delay)
        receive do
            {:req, {m_pid,m}} -> case numero do
                1 -> if (((worker_type == :omission) and (:random.uniform(100) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)), do: send(m_pid, suma(m))
                2 -> if (((worker_type == :omission) and (:random.uniform(100) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)), do: send(m_pid, suma_divisores_propios(m))
                3 -> if (((worker_type == :omission) and (:random.uniform(100) < 75)) or (worker_type == :timing) or (worker_type==:no_fault)), do: send(m_pid, lista_divisores_propios(m))
            end
        end
        loopI(worker_type, numero)
    end
end
