#include <string.h>   // NECESARIO para usar bcopy
// Ficheros necesarios para el manejo de sockets, direcciones, etc.
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <netdb.h>
#include <signal.h>
#include <errno.h>
#include <stdlib.h>  // Para atol
#include <stdio.h>  //  Manejo de ficheros
#include <fcntl.h>  //  PAra poder hacer open
// API de sockets seguros de OpenSSL
#include <openssl/ssl.h>
#include <openssl/err.h>

#define CHK_ERR(err,s) if ((err)==-1) { perror(s); exit(1);  }
#define CHK_NULL(x) if ((x)==NULL) { ERR_print_errors_fp(stderr); exit(-1); }
#define CHK_SSL(err) if ((err)==-1) { ERR_print_errors_fp(stderr); exit(-2); }

#define PUERTO (IPPORT_RESERVED + 40)  // Puerto tomado al azar
#define TAMBUF 1024 			// Maxima lectura/escritura

/* El cliente NO presenta certificado: solo necesita la CA del servidor para
 * verificar el certificado que este le envie. */
#define CA_CERT "certificados/s-ca_cert.pem"

/* Callback que exporta los secretos TLS para poder descifrar en Wireshark */
void key_log_cb(const SSL *ssl, const char *line) {
	FILE *f = fopen("keylog-ssl.log", "a");
	if (f) {
		fprintf(f, "%s\n", line);
		fclose(f);
	}
}

int main(int count, char *strings[]){
	SSL_CTX *ctx;
	SSL *ssl;
	const SSL_METHOD *method;
	int sock;
	int err, bytes_rec, k, i;
	long tam_fich;
	struct sockaddr_in serv;
	struct hostent *host;
	FILE *fd;
	char buf[TAMBUF];

	if ( count != 3 ){
		printf("Uso: %s <hostip> <filename>\n", strings[0]);
		exit(1);
	}

/*--- Inicializa el motor SSL y crea el contexto -------*/

	SSL_library_init();
	SSL_load_error_strings();

	method = TLS_client_method();
	ctx = SSL_CTX_new(method);
	CHK_NULL(ctx);

	/* Lista de cifrados y maximo TLS 1.2 (imprescindible para Wireshark) */
	err = SSL_CTX_set_cipher_list(ctx, "AES128-SHA256:AES256-CCM:AES256-GCM-SHA384");
	CHK_SSL(err);

	err = SSL_CTX_set_max_proto_version(ctx, TLS1_2_VERSION);
	CHK_SSL(err);

	/* CA de confianza para verificar al servidor */
	err = SSL_CTX_load_verify_locations(ctx, CA_CERT, NULL);
	CHK_SSL(err);

	/* Exige verificar el certificado del servidor */
	SSL_CTX_set_verify(ctx, SSL_VERIFY_PEER, NULL);
	SSL_CTX_set_verify_depth(ctx, 1);

	/* Exporta los secretos de sesion a keylog-ssl.log */
	SSL_CTX_set_keylog_callback(ctx, key_log_cb);

/*--- Crea el socket y conecta con el servidor ----------*/

	host = gethostbyname(strings[1]);

	sock = socket(PF_INET, SOCK_STREAM, 0);
	CHK_ERR(sock, "No crea socket");

	memset(&serv, 0, sizeof serv);
	serv.sin_family = AF_INET;
	serv.sin_port = htons(PUERTO);
	serv.sin_addr.s_addr = *(long *)(host->h_addr);

	err = connect(sock, (struct sockaddr *)&serv, sizeof serv);
	CHK_ERR(err, "No acepta conexion");

/*--- Nueva conexion TLS ---------------------------------*/

	ssl = SSL_new(ctx);		/* nuevo estado de conexion TLS */
	CHK_NULL(ssl);

	SSL_set_fd(ssl, sock);		/* asocia el socket a TLS */

	err = SSL_connect(ssl);		/* handshake TLS */
	CHK_SSL(err);

	printf("Conectado con cifrado %s\n", SSL_get_cipher(ssl));
	printf("Verificacion del servidor: %s\n",
	       SSL_get_verify_result(ssl) == X509_V_OK ? "OK" : "FALLO");

/*--- Recibe la cabecera con el tamano y el fichero ----*/

	memset(&buf, 0, TAMBUF);
	bytes_rec = SSL_read(ssl, buf, sizeof(tam_fich)-2);
	CHK_SSL(bytes_rec);

	if ( strncmp(buf, "OK:", 3) ){
		printf("Encontrado error en comando %s!!!\n",buf);
		SSL_shutdown(ssl);
		SSL_free(ssl);
		close(sock);
		SSL_CTX_free(ctx);
		exit(1);
	}
	tam_fich = atol(&buf[3]);

	// Recibir fichero del servidor
	if ((fd = fopen(strings[2], "w")) == NULL){
		perror("Abriendo fichero local");
		exit(1);
	}

	bytes_rec = 0;
	while(bytes_rec < tam_fich){
		k = SSL_read(ssl, buf, TAMBUF);

		if ((k <= 0)|| !strncmp(buf, "KO:" ,3)){
			perror("Leyendo respuesta. Abandono");
			SSL_shutdown(ssl);
			SSL_free(ssl);
			close(sock);
			fclose(fd);
			SSL_CTX_free(ctx);
			exit(1);
		}
		for (i=0; i<k; i++)
			if (putc(buf[i],fd)<0){
				perror("Escribiendo en el fichero local. Abandono");
				SSL_shutdown(ssl);
				SSL_free(ssl);
				close(sock);
				fclose(fd);
				SSL_CTX_free(ctx);
				exit(1);
			}
		bytes_rec += k;
	}

	fclose(fd);

	SSL_shutdown(ssl);
	SSL_free(ssl);
	close(sock);
	SSL_CTX_free(ctx);
	exit(0);
}
