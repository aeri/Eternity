# Para utilizar IEx.pry
require IEx

defmodule ServidorGV do
  @moduledoc """
      modulo del servicio de vistas
  """

  # Tipo estructura de datos que guarda el estado del servidor de vistas
  # COMPLETAR  con lo campos necesarios para gestionar
  # el estado del gestor de vistas
  defstruct num_vista: 0,
            primario: :undefined,
            copia: :undefined

  # Constantes
  @latidos_fallidos 4

  @intervalo_latidos 50

  @doc """
      Acceso externo para constante de latidos fallios
  """
  def latidos_fallidos() do
    @latidos_fallidos
  end

  @doc """
      acceso externo para constante intervalo latido
  """
  def intervalo_latidos() do
    @intervalo_latidos
  end

  @doc """
      Generar un estructura de datos vista inicial
  """
  def vista_inicial() do
    %{num_vista: 0, primario: :undefined, copia: :undefined}
  end

  @doc """
      Poner en marcha el servidor para gestión de vistas
      Devolver atomo que referencia al nuevo nodo Elixir
  """
  @spec startNodo(String.t(), String.t()) :: node
  def startNodo(nombre, maquina) do
    # fichero en curso
    NodoRemoto.start(nombre, maquina, __ENV__.file)
  end

  @doc """
      Poner en marcha servicio trás esperar al pleno funcionamiento del nodo
  """
  @spec startService(node) :: boolean
  def startService(nodoElixir) do
    NodoRemoto.esperaNodoOperativo(nodoElixir, __MODULE__)

    # Poner en marcha el código del gestor de vistas
    Node.spawn(nodoElixir, __MODULE__, :init_sv, [])
  end

  # ------------------- FUNCIONES PRIVADAS ----------------------------------

  # Estas 2 primeras deben ser defs para llamadas tipo (MODULE, funcion,[])
  def init_sv() do
    Process.register(self(), :servidor_gv)

    # otro proceso concurrente
    spawn(__MODULE__, :init_monitor, [self()])

    #### VUESTRO CODIGO DE INICIALIZACION
    bucle_recepcion(vista_inicial(), vista_inicial(), 0, 0, [])
  end

  def init_monitor(pid_principal) do
    send(pid_principal, :procesa_situacion_servidores)
    Process.sleep(@intervalo_latidos)
    init_monitor(pid_principal)
  end

  defp bucle_recepcion(tentativa, valida, primario, copia, nodosespera) do
    {tentativa, valida, primario, copia, nodosespera} =
      receive do
        {:latido, 0, nodo_emisor} ->
          if tentativa.primario == :undefined do
            if tentativa.num_vista == 0 do
              tentativa = %{
                num_vista: tentativa.num_vista + 1,
                primario: nodo_emisor,
                copia: tentativa.copia
              }

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, tentativa, tentativa == valida}
              )

              {tentativa, valida, primario, copia, nodosespera}
            else
              if tentativa.copia == :undefined do
                nodosespera = nodosespera ++ [nodo_emisor]

                tentativa = %{
                  num_vista: tentativa.num_vista + 1,
                  primario: tentativa.primario,
                  copia: hd(nodosespera)
                }

                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, tentativa, tentativa == valida}
                )

                {tentativa, valida, primario, copia, tl(nodosespera)}
              else
                tentativa = %{
                  num_vista: tentativa.num_vista + 1,
                  primario: tentativa.copia,
                  copia: nodo_emisor
                }

                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, tentativa, tentativa == valida}
                )

                {tentativa, valida, primario, copia, nodosespera}
              end
            end
          else
            if tentativa.copia == :undefined do
              tentativa = %{
                num_vista: tentativa.num_vista + 1,
                primario: tentativa.primario,
                copia: nodo_emisor
              }

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, tentativa, tentativa == valida}
              )

              {tentativa, valida, primario, copia, nodosespera}
            else
              if tentativa.primario == nodo_emisor do
                primario = 0

                if tentativa.num_vista != valida.num_vista do
                  # No se ha confirmado la vista antes de que caiga el primario
                  IO.puts("Error Grave: posible pérdida de datos")
                  # System.halt()
                  {vista_inicial(), vista_inicial(), 0, 0, []}
                else
                  nodosespera = nodosespera ++ [nodo_emisor]

                  tentativa = %{
                    num_vista: tentativa.num_vista + 1,
                    primario: tentativa.copia,
                    copia: hd(nodosespera)
                  }

                  send(
                    {:servidor_sa, nodo_emisor},
                    {:vista_tentativa, tentativa, tentativa == valida}
                  )

                  {tentativa, valida, primario, copia, tl(nodosespera)}
                end
              else
                if tentativa.copia == nodo_emisor do
                  nodosespera = nodosespera ++ [nodo_emisor]
                  copia = 0

                  tentativa = %{
                    num_vista: tentativa.num_vista + 1,
                    primario: tentativa.primario,
                    copia: hd(nodosespera)
                  }

                  send(
                    {:servidor_sa, nodo_emisor},
                    {:vista_tentativa, tentativa, tentativa == valida}
                  )

                  {tentativa, valida, primario, copia, tl(nodosespera)}
                else
                  send(
                    {:servidor_sa, nodo_emisor},
                    {:vista_tentativa, tentativa, tentativa == valida}
                  )

                  {tentativa, valida, primario, copia,
                   nodosespera ++ [nodo_emisor]}
                end
              end
            end
          end

        {:latido, n, nodo_emisor} ->
          if nodo_emisor == tentativa.primario do
            primario = 0

            if n == tentativa.num_vista do
              valida = tentativa

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, tentativa, tentativa == valida}
              )

              {tentativa, valida, primario, copia, nodosespera}
            else
              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, tentativa, tentativa == valida}
              )

              {tentativa, valida, primario, copia, nodosespera}
            end
          else
            if tentativa.copia == :undefined do
              tentativa = %{
                num_vista: tentativa.num_vista + 1,
                primario: tentativa.primario,
                copia: nodo_emisor
              }

              send(
                {:servidor_sa, nodo_emisor},
                {:vista_tentativa, tentativa, tentativa == valida}
              )

              {tentativa, valida, primario, copia, nodosespera}
            else
              if nodo_emisor == tentativa.copia do
                copia = 0

                send(
                  {:servidor_sa, nodo_emisor},
                  {:vista_tentativa, tentativa, tentativa == valida}
                )

                {tentativa, valida, primario, copia, nodosespera}
              else
                if Enum.member?(nodosespera, nodo_emisor) do
                  send(
                    {:servidor_sa, nodo_emisor},
                    {:vista_tentativa, tentativa, tentativa == valida}
                  )

                  {tentativa, valida, primario, copia, nodosespera}
                else
                  # Si el nodo no se encontraba ni como primario, ni copia,
                  # ni espera se añade como nodo en espera
                  nodosespera = nodosespera ++ [nodo_emisor]

                  send(
                    {:servidor_sa, nodo_emisor},
                    {:vista_tentativa, tentativa, tentativa == valida}
                  )

                  {tentativa, valida, primario, copia, nodosespera}
                end
              end
            end
          end

        {:obten_vista, pid} ->
	  #IO.puts "Tentativa"
	  #IO.puts tentativa.num_vista
	  #IO.puts tentativa.primario

	  #IO.puts "Valida"
	  #IO.puts valida.num_vista
	  #IO.puts valida.primario

          send(pid, {:vista_valida, valida, tentativa == valida})
          {tentativa, valida, primario, copia, nodosespera}

        :procesa_situacion_servidores ->
          if tentativa.primario != :undefined do
            primario = primario + 1
            copia = copia + 1

            if primario >= latidos_fallidos() do
              if tentativa.num_vista != valida.num_vista do
                # No se ha confirmado la vista antes de que caiga el primario
                IO.puts("Error Grave: posible pérdida de datos")
                # System.halt()
                {vista_inicial(), vista_inicial(), 0, 0, []}
              else
                primario = 0

                if length(nodosespera) > 0 do
                  tentativa = %{
                    num_vista: tentativa.num_vista + 1,
                    primario: tentativa.copia,
                    copia: hd(nodosespera)
                  }

                  {tentativa, valida, primario, copia, tl(nodosespera)}
                else
                  tentativa = %{
                    num_vista: tentativa.num_vista + 1,
                    primario: tentativa.copia,
                    copia: :undefined
                  }

                  {tentativa, valida, primario, copia, nodosespera}
                end
              end
            else
              if copia >= latidos_fallidos() do
                copia = 0

                if length(nodosespera) > 0 do
                  tentativa = %{
                    num_vista: tentativa.num_vista + 1,
                    primario: tentativa.primario,
                    copia: hd(nodosespera)
                  }

                  {tentativa, valida, primario, copia, tl(nodosespera)}
                else
                  tentativa = %{
                    num_vista: tentativa.num_vista + 1,
                    primario: tentativa.primario,
                    copia: :undefined
                  }

                  {tentativa, valida, primario, copia, nodosespera}
                end
              else
                {tentativa, valida, primario, copia, nodosespera}
              end
            end
          else
            {tentativa, valida, primario, copia, nodosespera}
          end
      end

    bucle_recepcion(tentativa, valida, primario, copia, nodosespera)
  end

  # OTRAS FUNCIONES PRIVADAS VUESTRAS
end
