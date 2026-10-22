#include <string.h>   // NECESARIO para usar bcopy
// Ficheros necesarios para el manejo de sockets, direcciones, etc.
#include <sys/socket.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <unistd.h>
#include <netdb.h>
#include <errno.h>
#include <sys/stat.h>  // Para fstat
#include <stdlib.h>  // Para atol
#include <stdio.h>  //  Manejo de ficheros
#include <fcntl.h>  //  Para poder hacer open
// API de sockets seguros de OpenSSL
#include "openssl/ssl.h"
#include "openssl/err.h"

#define CHK_ERR(err,s) if ((err)==-1) { perror(s); exit(1);  }
#define CHK_NULL(x) if ((x)==NULL) { ERR_print_errors_fp(stderr); exit(-1); }
#define CHK_SSL(err) if ((err)==-1) { ERR_print_errors_fp(stderr); exit(-3); }

#define PUERTO (IPPORT_RESERVED + 40)  // Puerto tomado al azar
#define TAMBUF 1460 			// Maxima lectura/escritura

/* Certificados del servidor. El cliente NO presenta certificado, por lo que
 * el servidor no carga la CA del cliente ni exige verificacion mutua. */
#define CERTFILE "certificados/s_cert.pem"
#define KEYFILE  "certificados/s_key.pem"

/* Igual que en la version TCP, pero escribiendo sobre el canal TLS */
void enviar_usuarios(SSL *ssl){
	int fp;  	// Descriptor del fichero a enviar
	struct stat f;	// Estructura de donde sacaremos el tama�o del fichero
	int i, total;
	char buf[TAMBUF];
	long int tam;	// tama�o del fichero, a leer de la estructura stat

	system("w > /tmp/file_users");

	if ((fp = open("/tmp/file_users", O_RDONLY)) < 0 ) {
		snprintf(buf, sizeof(buf), "KO: Error al abrir el fichero");
		SSL_write(ssl, buf, strlen(buf));
		return;
	}

	i = stat("/tmp/file_users", &f);
	if (i != 0) {
		snprintf(buf, sizeof(buf), "KO: Error stat");
		SSL_write(ssl, buf, strlen(buf));
		close(fp);
		return;
	}

	tam = f.st_size;
	sprintf(buf, "OK:%ld", tam);
	SSL_write(ssl, buf, strlen(buf));

	total = 0;
	while (total < tam){
		if ((i = read(fp, buf, TAMBUF))<0) {
			snprintf(buf, sizeof(buf), "KO: Error read file");
			SSL_write(ssl, buf, strlen(buf));
			perror("read fichero");
			close(fp);
			return;
		}
		if ((i = SSL_write(ssl, buf, i)) < 0){
			perror("write SSL");
			close(fp);
			return;
		}
		total += i;
	}

	close(fp);
	return;
}

int main(void){
	int s, c;	// sockets de conexion y dialogo
	int err;		// variable auxiliar
	int on = 1;		// opciones de socket
	struct sockaddr_in dir;
	SSL_CTX *ctx;		// contexto TLS
	SSL *ssl;		// estado de la conexion TLS
	const SSL_METHOD *method;

/*--- Inicializa el motor SSL y crea el contexto -------*/

	SSL_library_init();
	SSL_load_error_strings();	/* carga los mensajes de error */

	method = TLS_server_method();
	ctx = SSL_CTX_new(method);
	CHK_NULL(ctx);

	/* Certificado y clave privada del servidor */
	err = SSL_CTX_use_certificate_file(ctx, CERTFILE, SSL_FILETYPE_PEM);
	CHK_SSL(err);

	err = SSL_CTX_use_PrivateKey_file(ctx, KEYFILE, SSL_FILETYPE_PEM);
	CHK_SSL(err);

	err = SSL_CTX_check_private_key(ctx);
	CHK_ERR(err,"La clave privada no corresponde al certificado\n");

	/* NO se llama a SSL_CTX_load_verify_locations ni a SSL_CTX_set_verify:
	 * el cliente no presenta certificado (autenticacion solo del servidor). */

/*--- Crea el socket de escucha (TCP) ------------------*/

	s = socket(PF_INET, SOCK_STREAM, 0);
	CHK_ERR(s, "Apertura de socket");

	/* Permite reabrir el puerto aunque queden sockets en TIME_WAIT */
	setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));

	dir.sin_family = AF_INET;
	dir.sin_port = htons(PUERTO);
	dir.sin_addr.s_addr = htonl(INADDR_ANY);

	err = bind (s, (struct sockaddr *)&dir, sizeof(dir));
	CHK_ERR(err, "Bind");

	err = listen (s, 5);
	CHK_ERR(err, "Listen");

	do {
			c = accept(s, NULL, 0);
			CHK_ERR(c, "Accept");

			ssl = SSL_new(ctx);		/* nuevo estado TLS */
			CHK_NULL(ssl);

			SSL_set_fd(ssl, c);		/* asocia el socket a TLS */

			err = SSL_accept(ssl);		/* handshake TLS */
			CHK_SSL(err);

			printf("Cliente conectado (cifrado %s)\n", SSL_get_cipher(ssl));
			fflush(stdout);

			enviar_usuarios(ssl);

			SSL_shutdown(ssl);
			SSL_free(ssl);			/* libera el estado TLS */
			close(c);
		
		} while (1);
		
	close(s);
	SSL_CTX_free(ctx);
	exit(0);
}
