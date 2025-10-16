package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var (
	oidEmailAddress = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 9, 1}
)

func generateCSR(privKeyPath string, publicKeyPath string, csrPath string) {
	privKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		log.Fatalf("Unable to generate RSA private key: %v", err)
	}
	privKeyBytes, err := x509.MarshalPKCS8PrivateKey(privKey)
	if err != nil {
		log.Fatalf("Unable to serialize RSA private key to PKCS#8 container: %v", err)
	}
	privKeyBuffer, err := os.OpenFile(privKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		log.Fatalf("Unable to open RSA private key file for writing: %v", err)
	}
	defer privKeyBuffer.Close()

	err = pem.Encode(privKeyBuffer, &pem.Block{Type: "PRIVATE KEY", Bytes: privKeyBytes})
	if err != nil {
		log.Fatalf("Unable to persist RSA private key to disk: %v", err)
	}

	pubKeyBytes, err := x509.MarshalPKIXPublicKey(privKey.Public())
	if err != nil {
		log.Fatalf("Unable to serialize RSA public key to PKIX container: %v", err)
	}
	pubKeyBuffer, err := os.OpenFile(publicKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		log.Fatalf("Unable to open RSA public key file for writing: %v", err)
	}
	defer pubKeyBuffer.Close()

	err = pem.Encode(pubKeyBuffer, &pem.Block{Type: "PUBLIC KEY", Bytes: pubKeyBytes})
	if err != nil {
		log.Fatalf("Unable to persist RSA public key to disk: %v", err)
	}

	csr := x509.CertificateRequest{
		Subject: pkix.Name{
			CommonName:         "my-certificate",
			Country:            []string{"US"},
			Province:           []string{"Indiana"},
			Locality:           []string{"Indianapolis"},
			Organization:       []string{"ACME"},
			OrganizationalUnit: []string{"Fizz", "Buzz"},
			ExtraNames: []pkix.AttributeTypeAndValue{
				{
					Type: oidEmailAddress,
					Value: asn1.RawValue{
						Tag:   asn1.TagIA5String,
						Bytes: []byte("me@example.com"),
					},
				},
			},
		},
	}

	csrBytes, err := x509.CreateCertificateRequest(rand.Reader, &csr, privKey)
	if err != nil {
		log.Fatalf("Unable to generate certificate signing request: %v", err)
	}
	csrBuffer, err := os.OpenFile(csrPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		log.Fatalf("Unable to open CSR file for writing: %v", err)
	}
	defer csrBuffer.Close()

	err = pem.Encode(csrBuffer, &pem.Block{Type: "CERTIFICATE REQUEST", Bytes: csrBytes})
	if err != nil {
		log.Fatalf("Unable to persist certificate signing request to disk: %v", err)
	}
}

type PkiSignResponse struct {
	Data struct {
		CAChain      []string    `json:"ca_chain"`
		Certificate  string      `json:"certificate"`
		IssuingCA    string      `json:"issuing_ca"`
		Expiration   json.Number `json:"expiration"`
		SerialNumber string      `json:"serial_number"`
	} `json:"data"`
}

func signCertificate(csrPath string, certPath string, caPath string) {
	if err := os.Setenv("VAULT_FORMAT", "json"); err != nil {
		log.Fatalf("Unable to set environment variable: %v", err)
	}
	vaultWriteCmd := exec.Command("vault", "write", "pki/sign-verbatim/client", fmt.Sprintf("csr=@%s", csrPath), fmt.Sprintf("ttl=%d", 24*60*60 /* 24 hours */))
	out, err := vaultWriteCmd.Output()
	if err != nil {
		log.Fatalf("Failed to run `vault write` command: %v", err)
	}

	var resp PkiSignResponse
	err = json.Unmarshal(out, &resp)
	if err != nil {
		log.Fatalf("Unable to unmarshal JSON response from Vault: %v", err)
	}

	if len(resp.Data.CAChain) == 0 {
		log.Fatalln("No certificate authority chain was returned")
	}
	if err = os.WriteFile(caPath, []byte(strings.Join(resp.Data.CAChain, "\n")+"\n"), 0o644); err != nil {
		log.Fatalf("Unable to write CA bundle to file: %v", err)
	}
	if resp.Data.Certificate == "" {
		log.Fatalln("No certificate was issued")
	}
	if err = os.WriteFile(certPath, []byte(resp.Data.Certificate+"\n"), 0o644); err != nil {
		log.Fatalf("Unable to write issued certificate to file: %v", err)
	}
}

func main() {
	baseDir := filepath.Join("tmp", "tls")
	if err := os.MkdirAll(baseDir, os.ModePerm); err != nil {
		log.Fatalf("Unable to create directory: %v", err)
	}

	privkeyPath := filepath.Join(baseDir, "client.private.pem")
	pubkeyPath := filepath.Join(baseDir, "client.public.pem")
	csrPath := filepath.Join(baseDir, "client.csr.pem")
	certPath := filepath.Join(baseDir, "client.certificate.pem")
	caPath := filepath.Join(baseDir, "client.ca.pem")

	generateCSR(privkeyPath, pubkeyPath, csrPath)
	signCertificate(csrPath, certPath, caPath)
}
