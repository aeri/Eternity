defmodule Usuario do
	defp mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply) do
		receive do
			{pid, :chooseSeqNum}  ->
				new_requesting_critical_section = true
				new_our_sequence_number = highest_sequence_number + 1
				send(pid, {new_our_sequence_number, :ok})
				mutex(new_requesting_critical_section, new_our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, n, :asignOutstandingReply} ->
				new_outstanding_reply = n - 1
				send(pid, {:ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, new_outstanding_reply)
			{pid, :checkOutstandingReply} ->
				send(pid, {outstanding_reply, :ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, :release} ->
				new_requesting_critical_section = false
				send(pid, {:ok})
				mutex(new_requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, j, :checkDeferred} ->
				send(pid, {reply_deferred[j], :ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, j, value, :modifyDeferred} ->
				new_reply_deferred = List.replace_at(reply_deferred, j, value)
				send(pid, {:ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, new_reply_deferred, outstanding_reply)
			{pid, k, :maxSeq} ->
				if k > highest_sequence_number do
					new_highest_sequence_number = k
					send(pid, {:ok})
					mutex(requesting_critical_section, our_sequence_number, new_highest_sequence_number, reply_deferred, outstanding_reply)
				else
					send(pid, {:ok})
					mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
				end
			{pid, k, j, me, :checkDeferIt} ->
				if requesting_critical_section and ((k > our_sequence_number) or (k == our_sequence_number and j > me)) do
					send(pid, {true, :ok})
				else
					send(pid, {false, :ok})
				end
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, outstanding_reply)
			{pid, :subOutstandingReply} ->
				new_outstanding_reply = outstanding_reply - 1
				if new_outstanding_reply == 0 do
					send(pid, {:ok_0})
				end
				send(pid, {:ok})
				mutex(requesting_critical_section, our_sequence_number, highest_sequence_number, reply_deferred, new_outstanding_reply)
		end
	end

	defp distributed_critical_section(mypid, num, lista) do
		mensaje = IO.gets "Introduce mensaje\n"
		send(mypid, {:chooseSeqNum})
		receive do
			{_, numSeq, :ok} -> # Se queda bloqueado esperando un signal (:ok) del proceso mutex
				send(mypid, {length(lista), :asignOutstandingReply})
				receive do
					{_, :ok} ->
                        for node <- lista do
                            if node[1] != num do
                                send(node[0], {num, numSeq, :request})
                            end
                        end
                        receive do
                            {_, :ok_0} -> # Se espera a que haya una respuesta (:reply) del resto de nodos
                                for node <- lista do
                                    send(node[0], {mensaje, :mensaje}) # Al entrar a la seccion critica manda el mensaje a todos los nodos
                                end
                                send(mypid, {:release})
                                receive do
                                    {_, :ok} ->
                                        for node <- lista do
                                            send(mypid, {node[1], :checkDeferred})
                                            receive do
                                                {_, value, :ok} ->
                                                    if value do
                                                        send(mypid, {node[1], false, :modifyDeferred})
                                                        receive do
                                                            {_, :ok} ->
                                                                send(node[0], {:reply}) # Mandar un mensaje de REPLY al nodo
                                                        end
                                                    end
                                            end
                                        end
                                        distributed_critical_section(mypid, num, lista)
                                    end
                            end
                    end
            end
    end
	defp receive_request_messages(mypid, num) do
		receive do
			{node_pid, j, k, :request} ->
				send(mypid, {k, :maxSeq})
				receive do
					{_, :ok} ->
                        send(mypid, {k, j, num, :checkDeferIt})
                        receive do
                            {_, defer_it, :ok} ->
                                if defer_it do
                                    send(mypid, {j, true, :modifyDeferred})
                                    receive do
                                        {_, :ok} ->
                                            receive_request_messages(mypid, num)
                                    end
                                else
                                    send(node_pid, {:reply})
                                    receive_request_messages(mypid, num)
                                end
                        end
                end
        end
    end

	defp receive_reply_messages(mypid) do
		receive do
			{_, :reply} ->
                send(mypid, {:subOutstandingReply})
                receive do
                    {_, :ok} ->
                        receive_reply_messages(mypid)
                end
        end
	end
	
	defp show_messages() do
		receive do
			{pid, mensaje, :mensaje} ->
				IO.puts pid
				IO.puts mensaje
		end
		show_messages()
	end
	
	def init(mypid, lista, mynum) do
        spawn(fn->distributed_critical_section(mypid, mynum, lista)end)
        spawn(fn->receive_request_messages(mypid, mynum)end)
        spawn(fn->receive_reply_messages(mypid)end)
        spawn(fn->show_messages()end)
        mutex(false, false, 0, List.duplicate(false, length(lista)), length(lista) - 1)
    end
end
