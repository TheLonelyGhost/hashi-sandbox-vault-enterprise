package main

import (
	"bytes"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/asn1"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

var (
	oidEmailAddress = asn1.ObjectIdentifier{1, 2, 840, 113549, 1, 9, 1}
)

func generateCSR(privKeyPath string, publicKeyPath string, csrPath string) (err error) {
	privKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		err = errors.Join(errors.New("unable to generate RSA private key"), err)
		return
	}
	privKeyBytes, err := x509.MarshalPKCS8PrivateKey(privKey)
	if err != nil {
		err = errors.Join(errors.New("unable to serialize RSA private key to PKCS#8 container"), err)
		return
	}
	privKeyBuffer, err := os.OpenFile(privKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		err = errors.Join(errors.New("unable to open RSA private key destination file for writing"), err)
		return
	}
	defer privKeyBuffer.Close()

	err = pem.Encode(privKeyBuffer, &pem.Block{Type: "PRIVATE KEY", Bytes: privKeyBytes})
	if err != nil {
		err = errors.Join(errors.New("unable to persist RSA private key to disk"), err)
		return
	}

	pubKeyBytes, err := x509.MarshalPKIXPublicKey(privKey.Public())
	if err != nil {
		err = errors.Join(errors.New("unable to serialize RSA public key to PKIX container"), err)
		return
	}
	pubKeyBuffer, err := os.OpenFile(publicKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		err = errors.Join(errors.New("unable to open RSA public key destination file for writing"), err)
		return
	}
	defer pubKeyBuffer.Close()

	err = pem.Encode(pubKeyBuffer, &pem.Block{Type: "PUBLIC KEY", Bytes: pubKeyBytes})
	if err != nil {
		err = errors.Join(errors.New("unable to persist RSA public key to disk"), err)
		return
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
		err = errors.Join(errors.New("unable to generate certificate signing request"), err)
		return
	}
	csrBuffer, err := os.OpenFile(csrPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o644)
	if err != nil {
		err = errors.Join(errors.New("unable to open certificate signing request's destination file for writing"), err)
		return
	}
	defer csrBuffer.Close()

	err = pem.Encode(csrBuffer, &pem.Block{Type: "CERTIFICATE REQUEST", Bytes: csrBytes})
	if err != nil {
		err = errors.Join(errors.New("unable to persist certificate signing request to disk"), err)
	}
	return
}

func newVaultClient() (vault http.Client, err error) {
	certPool, err := x509.SystemCertPool()
	if err != nil {
		err = errors.Join(errors.New("unable to retrieve system-wide certificate authority trust store"), err)
		return
	}
	serverCertCA, err := os.ReadFile(os.Getenv("VAULT_CACERT"))
	if err != nil {
		log.Fatalf("Vault server's certificate authority file could not be read: %v", err)
	}
	_ = certPool.AppendCertsFromPEM(serverCertCA)

	vault = http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				RootCAs: certPool,
			},
		},
	}

	return
}

type PkiSignRequest struct {
	CertificateSigningRequest string `json:"csr"`
	TimeToLive                string `json:"ttl"`
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

func requestSignedPKICertificate(vault http.Client, req PkiSignRequest) (resp PkiSignResponse, err error) {
	reqBytes, err := json.Marshal(req)
	if err != nil {
		err = errors.Join(errors.New("unable to marshal JSON in HTTP request to Vault"), err)
		return
	}
	reqBuffer := bytes.NewBuffer(reqBytes)
	request, err := http.NewRequest("PUT", fmt.Sprintf("%s/v1/pki/sign-verbatim/client", os.Getenv("VAULT_ADDR")), reqBuffer)
	if err != nil {
		err = errors.Join(errors.New("unable to queue up a PUT operation in the HTTP client"), err)
		return
	}
	request.Header.Add("X-Vault-Token", os.Getenv("VAULT_TOKEN"))
	respRaw, err := vault.Do(request)
	if err != nil {
		err = errors.Join(errors.New("unable to complete HTTP PUT operation against Vault"), err)
		return
	}
	if respRaw.StatusCode != http.StatusOK {
		err = fmt.Errorf("Unexpected HTTP response from Vault: %s", respRaw.Status)
		return
	}
	respBytes, err := io.ReadAll(respRaw.Body)
	if err != nil {
		err = errors.Join(errors.New("unable to read entire Vault response"), err)
		return
	}
	err = json.Unmarshal(respBytes, &resp)
	if err != nil {
		err = errors.Join(errors.New("unable to unmarshal Vault response as valid JSON"), err)
	}
	return
}

func signCertificate(csrPath string, certPath string, caPath string) (err error) {
	vault, err := newVaultClient()
	if err != nil {
		err = errors.Join(errors.New("unable to setup Vault client"), err)
		return
	}

	csrContent, err := os.ReadFile(csrPath)
	if err != nil {
		err = errors.Join(errors.New("unable to read CSR content from filesystem"), err)
		return
	}
	resp, err := requestSignedPKICertificate(vault, PkiSignRequest{
		CertificateSigningRequest: string(csrContent),
		TimeToLive:                fmt.Sprintf("%d", 24*60*60), // 24 hours
	})
	if err != nil {
		err = errors.Join(errors.New("unable to request signed certificate from Vault"), err)
		return
	}

	if len(resp.Data.CAChain) == 0 {
		err = errors.New("no certificate authority chain was returned by Vault")
		return
	}
	if err = os.WriteFile(caPath, []byte(strings.Join(resp.Data.CAChain, "\n")+"\n"), 0o644); err != nil {
		err = errors.Join(errors.New("unable to write CA bundle to file"), err)
		return
	}
	if resp.Data.Certificate == "" {
		err = errors.New("no certificate was issued")
		return
	}
	if err = os.WriteFile(certPath, []byte(resp.Data.Certificate+"\n"), 0o644); err != nil {
		err = errors.Join(errors.New("unable to write issued certificate to file"), err)
	}
	return
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

	if err := generateCSR(privkeyPath, pubkeyPath, csrPath); err != nil {
		log.Fatalf("Unable to generate certificate signing request: %v", err)
	}
	if err := signCertificate(csrPath, certPath, caPath); err != nil {
		log.Fatalf("Unable to sign certificate: %v", err)
	}
}
